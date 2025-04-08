//+------------------------------------------------------------------+
//|                                      TrendStrengthIndex.mq5 |
//|                     Copyright 2025, Algorithmic Trading Project |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Algorithmic Trading Project"
#property link      ""
#property version   "1.00"

// Indicator settings
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

// Plot settings
#property indicator_label1  "Strong Bullish"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "Strong Bearish"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3  "Trend Strength"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

// Input parameters
input int      EMA_Fast_Period   = 8;      // Fast EMA Period
input int      EMA_Slow_Period   = 21;     // Slow EMA Period
input int      MACD_Fast_Period  = 12;     // MACD Fast EMA Period
input int      MACD_Slow_Period  = 26;     // MACD Slow EMA Period
input int      MACD_Signal_Period= 9;      // MACD Signal Period
input int      RSI_Period        = 14;     // RSI Period
input int      ATR_Period        = 14;     // ATR Period
input double   Threshold         = 0.7;    // Trend Strength Threshold (0-1)

// Indicator buffers
double BullishBuffer[];
double BearishBuffer[];
double TrendStrengthBuffer[];

// Indicator handles
int EMA_Fast_Handle;
int EMA_Slow_Handle;
int MACD_Handle;
int RSI_Handle;
int ATR_Handle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator buffers
   SetIndexBuffer(0, BullishBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, BearishBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, TrendStrengthBuffer, INDICATOR_DATA);
   
   // Set arrow codes
   PlotIndexSetInteger(0, PLOT_ARROW, 233); // Bullish arrow
   PlotIndexSetInteger(1, PLOT_ARROW, 234); // Bearish arrow
   
   // Initialize indicator handles
   EMA_Fast_Handle = iMA(_Symbol, PERIOD_CURRENT, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   EMA_Slow_Handle = iMA(_Symbol, PERIOD_CURRENT, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   MACD_Handle = iMACD(_Symbol, PERIOD_CURRENT, MACD_Fast_Period, MACD_Slow_Period, MACD_Signal_Period, PRICE_CLOSE);
   RSI_Handle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   ATR_Handle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   
   // Check if indicators were created successfully
   if(EMA_Fast_Handle == INVALID_HANDLE || EMA_Slow_Handle == INVALID_HANDLE || 
      MACD_Handle == INVALID_HANDLE || RSI_Handle == INVALID_HANDLE || ATR_Handle == INVALID_HANDLE)
   {
      Print("Error creating indicators: ", GetLastError());
      return(INIT_FAILED);
   }
   
   // Set indicator digits and labels
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   IndicatorSetString(INDICATOR_SHORTNAME, "Trend Strength Index");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Check for minimum bars required
   int min_bars = MathMax(EMA_Slow_Period, MathMax(MACD_Slow_Period + MACD_Signal_Period, RSI_Period));
   if(rates_total < min_bars) return(0);
   
   // Calculate the starting bar
   int start;
   if(prev_calculated == 0)
   {
      // First calculation, fill all buffers with empty values
      ArrayInitialize(BullishBuffer, EMPTY_VALUE);
      ArrayInitialize(BearishBuffer, EMPTY_VALUE);
      ArrayInitialize(TrendStrengthBuffer, EMPTY_VALUE);
      start = min_bars + 10; // Add some extra bars for indicator calculations
   }
   else
   {
      start = prev_calculated - 1;
   }
   
   // Arrays for indicator values
   double ema_fast[], ema_slow[], macd_main[], macd_signal[], rsi[], atr[];
   
   // Set arrays as timeseries
   ArraySetAsSeries(ema_fast, true);
   ArraySetAsSeries(ema_slow, true);
   ArraySetAsSeries(macd_main, true);
   ArraySetAsSeries(macd_signal, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(close, true);
   
   // Copy indicator data
   if(CopyBuffer(EMA_Fast_Handle, 0, 0, rates_total, ema_fast) <= 0) return(0);
   if(CopyBuffer(EMA_Slow_Handle, 0, 0, rates_total, ema_slow) <= 0) return(0);
   if(CopyBuffer(MACD_Handle, 0, 0, rates_total, macd_main) <= 0) return(0);
   if(CopyBuffer(MACD_Handle, 1, 0, rates_total, macd_signal) <= 0) return(0);
   if(CopyBuffer(RSI_Handle, 0, 0, rates_total, rsi) <= 0) return(0);
   if(CopyBuffer(ATR_Handle, 0, 0, rates_total, atr) <= 0) return(0);
   
   // Main calculation loop
   for(int i = start; i > 0; i--)
   {
      // Calculate trend strength based on multiple factors
      double ema_factor = (ema_fast[i] > ema_slow[i]) ? 1.0 : -1.0;
      double macd_factor = (macd_main[i] > macd_signal[i]) ? 1.0 : -1.0;
      double rsi_factor = 0.0;
      
      // RSI factor calculation (scaled from -1 to +1)
      if(rsi[i] > 70) rsi_factor = 1.0;
      else if(rsi[i] < 30) rsi_factor = -1.0;
      else rsi_factor = (rsi[i] - 50) / 20.0; // Linear scaling from 30-70 to -1 to +1
      
      // Combine all factors to get trend strength (-1 to +1 range)
      double trend_strength = (ema_factor * 0.4) + (macd_factor * 0.4) + (rsi_factor * 0.2);
      
      // Store trend strength value
      TrendStrengthBuffer[i] = trend_strength;
      
      // Set bullish/bearish signals based on threshold
      if(trend_strength > Threshold)
      {
         BullishBuffer[i] = low[i] - atr[i] * 0.5; // Position below the candle
         BearishBuffer[i] = EMPTY_VALUE;
      }
      else if(trend_strength < -Threshold)
      {
         BearishBuffer[i] = high[i] + atr[i] * 0.5; // Position above the candle
         BullishBuffer[i] = EMPTY_VALUE;
      }
      else
      {
         BullishBuffer[i] = EMPTY_VALUE;
         BearishBuffer[i] = EMPTY_VALUE;
      }
   }
   
   // Return calculated bars
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   IndicatorRelease(EMA_Fast_Handle);
   IndicatorRelease(EMA_Slow_Handle);
   IndicatorRelease(MACD_Handle);
   IndicatorRelease(RSI_Handle);
   IndicatorRelease(ATR_Handle);
}