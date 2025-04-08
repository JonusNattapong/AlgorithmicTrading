//+------------------------------------------------------------------+
//|                                            MA_RSI_Strategy.mq5 |
//|                     Copyright 2025, Algorithmic Trading Project |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Algorithmic Trading Project"
#property link      ""
#property version   "1.00"
#property strict

// Input parameters
input int      FastMA_Period = 10;   // Fast Moving Average period
input int      SlowMA_Period = 20;   // Slow Moving Average period
input int      RSI_Period    = 14;   // RSI period
input double   RSI_Upper     = 70;   // RSI upper level
input double   RSI_Lower     = 30;   // RSI lower level
input double   LotSize       = 0.1;  // Trading lot size
input int      StopLoss      = 100;  // Stop Loss in points
input int      TakeProfit    = 200;  // Take Profit in points
input int      MagicNumber   = 12345;// EA identifier

// Global variables
int FastMA_Handle;
int SlowMA_Handle;
int RSI_Handle;
int OnInit_Counter = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize indicators
   FastMA_Handle = iMA(_Symbol, PERIOD_CURRENT, FastMA_Period, 0, MODE_SMA, PRICE_CLOSE);
   SlowMA_Handle = iMA(_Symbol, PERIOD_CURRENT, SlowMA_Period, 0, MODE_SMA, PRICE_CLOSE);
   RSI_Handle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   
   // Check if indicators initialized successfully
   if(FastMA_Handle == INVALID_HANDLE || SlowMA_Handle == INVALID_HANDLE || RSI_Handle == INVALID_HANDLE)
   {
      Print("Error initializing indicators: ", GetLastError());
      return(INIT_FAILED);
   }
   
   OnInit_Counter++;
   Print("Expert Advisor initialized successfully. OnInit call #", OnInit_Counter);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   IndicatorRelease(FastMA_Handle);
   IndicatorRelease(SlowMA_Handle);
   IndicatorRelease(RSI_Handle);
   
   Print("Expert Advisor removed. Reason code: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if we already have a position
   if(PositionsTotal() > 0) return;
   
   // Define arrays for indicator values
   double FastMA[], SlowMA[], RSI[];
   ArraySetAsSeries(FastMA, true);
   ArraySetAsSeries(SlowMA, true);
   ArraySetAsSeries(RSI, true);
   
   // Get indicator values
   CopyBuffer(FastMA_Handle, 0, 0, 3, FastMA);
   CopyBuffer(SlowMA_Handle, 0, 0, 3, SlowMA);
   CopyBuffer(RSI_Handle, 0, 0, 3, RSI);
   
   // Check for entry conditions
   bool buyCond = (FastMA[1] > SlowMA[1] && RSI[1] < RSI_Lower);
   bool sellCond = (FastMA[1] < SlowMA[1] && RSI[1] > RSI_Upper);
   
   // Trading logic
   if(buyCond)
   {
      OpenPosition(ORDER_TYPE_BUY);
   }
   else if(sellCond)
   {
      OpenPosition(ORDER_TYPE_SELL);
   }
}

//+------------------------------------------------------------------+
//| Open a new position                                              |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   double price, sl, tp;
   
   // Set price, stop loss and take profit levels based on order type
   if(orderType == ORDER_TYPE_BUY)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = price - StopLoss * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      tp = price + TakeProfit * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   }
   else // ORDER_TYPE_SELL
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = price + StopLoss * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      tp = price - TakeProfit * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   }
   
   // Prepare trade request
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "MA-RSI Strategy";
   
   // Send the trade request
   if(!OrderSend(request, result))
   {
      Print("OrderSend error: ", GetLastError());
      return;
   }
   
   Print("Order sent successfully. Ticket: ", result.order);
}