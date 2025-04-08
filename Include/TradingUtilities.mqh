//+------------------------------------------------------------------+
//|                                    TradingUtilities.mqh |
//|                     Copyright 2025, Algorithmic Trading Project |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Algorithmic Trading Project"
#property link      ""
#property version   "1.00"

// Include standard libraries
#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>

// Global trading object
CTrade Trade;

//+------------------------------------------------------------------+
//| Risk Management Functions                                         |
//+------------------------------------------------------------------+

//--- Calculate lot size based on risk percentage
double CalculateLotSize(string symbol, double riskPercent, double slPoints)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (riskPercent / 100.0);
   
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double pointValue = tickValue / tickSize;
   
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   
   // Calculate lot size based on risk
   double calculatedLot = NormalizeDouble(riskAmount / (slPoints * pointValue), 2);
   
   // Adjust to lot step
   calculatedLot = MathFloor(calculatedLot / lotStep) * lotStep;
   
   // Ensure lot size is within allowed range
   calculatedLot = MathMax(minLot, MathMin(maxLot, calculatedLot));
   
   return calculatedLot;
}

//--- Check if trading is allowed based on time
bool IsTradingAllowed(int startHour = 0, int startMinute = 0, int endHour = 23, int endMinute = 59)
{
   datetime currentTime = TimeCurrent();
   MqlDateTime currentTimeStruct;
   TimeToStruct(currentTime, currentTimeStruct);
   
   // Convert current time to minutes since day start
   int currentTimeMinutes = (currentTimeStruct.hour * 60) + currentTimeStruct.min;
   int startTimeMinutes = (startHour * 60) + startMinute;
   int endTimeMinutes = (endHour * 60) + endMinute;
   
   // Check if current time is within allowed range
   if(startTimeMinutes <= endTimeMinutes)
   {
      // Normal time range within the same day
      return (currentTimeMinutes >= startTimeMinutes && currentTimeMinutes <= endTimeMinutes);
   }
   else
   {
      // Time range spans across midnight
      return (currentTimeMinutes >= startTimeMinutes || currentTimeMinutes <= endTimeMinutes);
   }
}

//+------------------------------------------------------------------+
//| Order Management Functions                                        |
//+------------------------------------------------------------------+

//--- Open market order with risk management
bool OpenMarketOrder(
   ENUM_ORDER_TYPE orderType, 
   string symbol, 
   double lotSize, 
   double slPoints, 
   double tpPoints, 
   string comment = "", 
   ulong magicNumber = 0
)
{
   // Get current prices
   double price = (orderType == ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(symbol, SYMBOL_BID);
                  
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // Calculate SL and TP levels
   double sl = 0, tp = 0;
   
   if(slPoints > 0)
   {
      sl = (orderType == ORDER_TYPE_BUY) ? 
           price - (slPoints * point) : 
           price + (slPoints * point);
   }
   
   if(tpPoints > 0)
   {
      tp = (orderType == ORDER_TYPE_BUY) ? 
           price + (tpPoints * point) : 
           price - (tpPoints * point);
   }
   
   // Set trading parameters
   Trade.SetExpertMagicNumber(magicNumber);
   Trade.SetDeviationInPoints(10); // Allow 10 points of slippage
   Trade.SetMarginMode();
   
   // Execute the trade
   bool result = false;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      result = Trade.Buy(lotSize, symbol, price, sl, tp, comment);
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      result = Trade.Sell(lotSize, symbol, price, sl, tp, comment);
   }
   
   if(!result)
   {
      Print("Failed to open order. Error: ", GetLastError());
   }
   
   return result;
}

//--- Close all positions for a specific symbol or for all symbols
bool CloseAllPositions(string symbol = "", ulong magicNumber = 0)
{
   bool success = true;
   
   // Loop through all open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      // Get position ticket
      ulong ticket = PositionGetTicket(i);
      
      // Skip if position selection failed
      if(!PositionSelectByTicket(ticket))
         continue;
         
      // Get position symbol and magic number
      string posSymbol = PositionGetString(POSITION_SYMBOL);
      ulong posMagic = PositionGetInteger(POSITION_MAGIC);
      
      // Check if position matches criteria
      if((symbol == "" || symbol == posSymbol) && 
         (magicNumber == 0 || magicNumber == posMagic))
      {
         // Close the position
         if(!Trade.PositionClose(ticket))
         {
            Print("Failed to close position #", ticket, ". Error: ", GetLastError());
            success = false;
         }
      }
   }
   
   return success;
}

//+------------------------------------------------------------------+
//| Technical Analysis Functions                                      |
//+------------------------------------------------------------------+

//--- Determine trend direction using moving averages
int DetermineTrend(
   string symbol, 
   ENUM_TIMEFRAMES timeframe, 
   int fastMAPeriod = 20, 
   int slowMAPeriod = 50
)
{
   // Get MA handles
   int fastMAHandle = iMA(symbol, timeframe, fastMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   int slowMAHandle = iMA(symbol, timeframe, slowMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   if(fastMAHandle == INVALID_HANDLE || slowMAHandle == INVALID_HANDLE)
   {
      Print("Failed to create MA indicators. Error: ", GetLastError());
      return 0; // No trend (neutral)
   }
   
   // Arrays for MA values
   double fastMA[], slowMA[];
   ArraySetAsSeries(fastMA, true);
   ArraySetAsSeries(slowMA, true);
   
   // Copy MA values
   if(CopyBuffer(fastMAHandle, 0, 0, 3, fastMA) <= 0 ||
      CopyBuffer(slowMAHandle, 0, 0, 3, slowMA) <= 0)
   {
      Print("Failed to copy MA values. Error: ", GetLastError());
      
      // Release indicator handles
      IndicatorRelease(fastMAHandle);
      IndicatorRelease(slowMAHandle);
      
      return 0; // No trend (neutral)
   }
   
   // Release indicator handles
   IndicatorRelease(fastMAHandle);
   IndicatorRelease(slowMAHandle);
   
   // Determine trend
   if(fastMA[0] > slowMA[0] && fastMA[1] > slowMA[1])
   {
      return 1; // Bullish trend
   }
   else if(fastMA[0] < slowMA[0] && fastMA[1] < slowMA[1])
   {
      return -1; // Bearish trend
   }
   
   return 0; // No clear trend
}

//--- Check if price has broken a support/resistance level
bool IsPriceBreakout(
   string symbol, 
   ENUM_TIMEFRAMES timeframe, 
   double level, 
   bool isBreakingUp, 
   int lookbackBars = 3
)
{
   double close[];
   ArraySetAsSeries(close, true);
   
   if(CopyClose(symbol, timeframe, 0, lookbackBars + 1, close) <= 0)
   {
      Print("Failed to copy price data. Error: ", GetLastError());
      return false;
   }
   
   if(isBreakingUp)
   {
      // Check for upward breakout
      // Previous bars were below the level, current bar is above
      for(int i = 1; i <= lookbackBars; i++)
      {
         if(close[i] >= level)
            return false; // Earlier bar was already above the level
      }
      
      return (close[0] > level); // Current bar is above the level
   }
   else
   {
      // Check for downward breakout
      // Previous bars were above the level, current bar is below
      for(int i = 1; i <= lookbackBars; i++)
      {
         if(close[i] <= level)
            return false; // Earlier bar was already below the level
      }
      
      return (close[0] < level); // Current bar is below the level
   }
}

//+------------------------------------------------------------------+
//| Market Data Functions                                             |
//+------------------------------------------------------------------+

//--- Calculate Average True Range (ATR)
double GetATR(string symbol, ENUM_TIMEFRAMES timeframe, int period = 14)
{
   int atrHandle = iATR(symbol, timeframe, period);
   
   if(atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator. Error: ", GetLastError());
      return 0;
   }
   
   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   
   if(CopyBuffer(atrHandle, 0, 0, 1, atrValues) <= 0)
   {
      Print("Failed to copy ATR values. Error: ", GetLastError());
      IndicatorRelease(atrHandle);
      return 0;
   }
   
   IndicatorRelease(atrHandle);
   
   return atrValues[0];
}

//--- Get the highest high and lowest low for a specific lookback period
bool GetPriceRange(
   string symbol, 
   ENUM_TIMEFRAMES timeframe, 
   int lookbackBars, 
   double &highestHigh, 
   double &lowestLow
)
{
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyHigh(symbol, timeframe, 0, lookbackBars, high) <= 0 ||
      CopyLow(symbol, timeframe, 0, lookbackBars, low) <= 0)
   {
      Print("Failed to copy price data. Error: ", GetLastError());
      return false;
   }
   
   highestHigh = high[ArrayMaximum(high, 0, lookbackBars)];
   lowestLow = low[ArrayMinimum(low, 0, lookbackBars)];
   
   return true;
}

//+------------------------------------------------------------------+
//| Position Analysis Functions                                       |
//+------------------------------------------------------------------+

//--- Calculate total profit/loss for open positions
double GetTotalPositionProfitLoss(string symbol = "", ulong magicNumber = 0)
{
   double totalPL = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      
      if(!PositionSelectByTicket(ticket))
         continue;
         
      string posSymbol = PositionGetString(POSITION_SYMBOL);
      ulong posMagic = PositionGetInteger(POSITION_MAGIC);
      
      if((symbol == "" || symbol == posSymbol) && 
         (magicNumber == 0 || magicNumber == posMagic))
      {
         totalPL += PositionGetDouble(POSITION_PROFIT);
      }
   }
   
   return totalPL;
}

//--- Check if there are any open positions for a specific symbol
bool HasOpenPositions(string symbol = "", ulong magicNumber = 0)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      
      if(!PositionSelectByTicket(ticket))
         continue;
         
      string posSymbol = PositionGetString(POSITION_SYMBOL);
      ulong posMagic = PositionGetInteger(POSITION_MAGIC);
      
      if((symbol == "" || symbol == posSymbol) && 
         (magicNumber == 0 || magicNumber == posMagic))
      {
         return true; // Found at least one matching position
      }
   }
   
   return false; // No matching positions found
}