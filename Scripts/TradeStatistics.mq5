//+------------------------------------------------------------------+
//|                                   TradeStatistics.mq5 |
//|                     Copyright 2025, Algorithmic Trading Project |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Algorithmic Trading Project"
#property link      ""
#property version   "1.00"
#property script_show_inputs

// Input parameters
input string   Symbol_Input      = "";        // Symbol (empty = current)
input datetime Start_Date        = D'2024.01.01 00:00';  // Start date
input datetime End_Date          = D'2024.12.31 23:59';  // End date
input int      Magic_Number      = 0;         // Magic number (0 = all)
input string   Comment_Filter    = "";        // Comment filter (empty = all)
input string   ReportFileName    = "TradingReport";  // Report file name

// Statistics variables
int      totalTrades        = 0;
int      winningTrades      = 0;
int      losingTrades       = 0;
double   grossProfit        = 0;
double   grossLoss          = 0;
double   netProfit          = 0;
double   maxDrawdown        = 0;
double   profitFactor       = 0;
double   winRate            = 0;
double   avgWin             = 0;
double   avgLoss            = 0;
double   expectancy         = 0;
int      consecutiveWins    = 0;
int      consecutiveLosses  = 0;
int      maxConsecutiveWins = 0;
int      maxConsecutiveLosses = 0;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   // Use current symbol if not specified
   string symbol = (Symbol_Input == "") ? _Symbol : Symbol_Input;
   
   // Initialize variables
   ResetStatistics();
   
   // Select history for the given period
   HistorySelect(Start_Date, End_Date);
   int totalDeals = HistoryDealsTotal();
   
   // Process all deals
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      
      // Skip if deal selection failed
      if(!HistoryDealSelect(dealTicket))
         continue;
         
      // Get deal properties
      string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      ulong dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      string dealComment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
      ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      
      // Skip deals that don't match filter criteria
      if(symbol != "" && dealSymbol != symbol) continue;
      if(Magic_Number != 0 && dealMagic != Magic_Number) continue;
      if(Comment_Filter != "" && StringFind(dealComment, Comment_Filter) < 0) continue;
      
      // Only process deals that are trade exits
      if(dealEntry != DEAL_ENTRY_OUT) continue;
      
      // Update statistics
      UpdateStatistics(dealProfit);
   }
   
   // Calculate final statistics
   CalculateStatistics();
   
   // Display results and generate report
   DisplayResults();
   SaveReportToFile(symbol);
}

//+------------------------------------------------------------------+
//| Reset all statistics variables                                    |
//+------------------------------------------------------------------+
void ResetStatistics()
{
   totalTrades = 0;
   winningTrades = 0;
   losingTrades = 0;
   grossProfit = 0;
   grossLoss = 0;
   netProfit = 0;
   maxDrawdown = 0;
   profitFactor = 0;
   winRate = 0;
   avgWin = 0;
   avgLoss = 0;
   expectancy = 0;
   consecutiveWins = 0;
   consecutiveLosses = 0;
   maxConsecutiveWins = 0;
   maxConsecutiveLosses = 0;
}

//+------------------------------------------------------------------+
//| Update statistics with a new trade result                         |
//+------------------------------------------------------------------+
void UpdateStatistics(double profit)
{
   totalTrades++;
   
   // Update profit/loss statistics
   if(profit > 0)
   {
      winningTrades++;
      grossProfit += profit;
      
      // Update consecutive wins/losses
      consecutiveWins++;
      consecutiveLosses = 0;
      
      if(consecutiveWins > maxConsecutiveWins)
         maxConsecutiveWins = consecutiveWins;
   }
   else if(profit < 0)
   {
      losingTrades++;
      grossLoss += MathAbs(profit);
      
      // Update consecutive wins/losses
      consecutiveLosses++;
      consecutiveWins = 0;
      
      if(consecutiveLosses > maxConsecutiveLosses)
         maxConsecutiveLosses = consecutiveLosses;
   }
   
   // Update net profit and drawdown
   netProfit += profit;
   
   static double highWaterMark = 0;
   if(netProfit > highWaterMark)
   {
      highWaterMark = netProfit;
   }
   else
   {
      double currentDrawdown = highWaterMark - netProfit;
      if(currentDrawdown > maxDrawdown)
         maxDrawdown = currentDrawdown;
   }
}

//+------------------------------------------------------------------+
//| Calculate final statistics                                       |
//+------------------------------------------------------------------+
void CalculateStatistics()
{
   // Calculate win rate
   if(totalTrades > 0)
      winRate = (double)winningTrades / totalTrades * 100;
      
   // Calculate average win and loss
   if(winningTrades > 0)
      avgWin = grossProfit / winningTrades;
      
   if(losingTrades > 0)
      avgLoss = grossLoss / losingTrades;
      
   // Calculate profit factor
   if(grossLoss > 0)
      profitFactor = grossProfit / grossLoss;
   else if(grossProfit > 0)
      profitFactor = 1000; // To indicate a very high profit factor when there are no losses
   
   // Calculate expectancy (average profit/loss per trade)
   if(totalTrades > 0)
      expectancy = netProfit / totalTrades;
}

//+------------------------------------------------------------------+
//| Display results to the user                                      |
//+------------------------------------------------------------------+
void DisplayResults()
{
   string message = 
      "====== TRADING STATISTICS REPORT ======\n\n" +
      "Period: " + TimeToString(Start_Date, TIME_DATE) + " to " + TimeToString(End_Date, TIME_DATE) + "\n\n" +
      "Total Trades: " + IntegerToString(totalTrades) + "\n" +
      "Winning Trades: " + IntegerToString(winningTrades) + " (" + DoubleToString(winRate, 2) + "%)\n" +
      "Losing Trades: " + IntegerToString(losingTrades) + " (" + DoubleToString(100 - winRate, 2) + "%)\n\n" +
      "Gross Profit: " + DoubleToString(grossProfit, 2) + "\n" +
      "Gross Loss: " + DoubleToString(grossLoss, 2) + "\n" +
      "Net Profit: " + DoubleToString(netProfit, 2) + "\n\n" +
      "Profit Factor: " + DoubleToString(profitFactor, 2) + "\n" +
      "Max Drawdown: " + DoubleToString(maxDrawdown, 2) + "\n" +
      "Average Win: " + DoubleToString(avgWin, 2) + "\n" +
      "Average Loss: " + DoubleToString(avgLoss, 2) + "\n" +
      "Expectancy: " + DoubleToString(expectancy, 2) + " per trade\n\n" +
      "Max Consecutive Wins: " + IntegerToString(maxConsecutiveWins) + "\n" +
      "Max Consecutive Losses: " + IntegerToString(maxConsecutiveLosses) + "\n\n" +
      "Report saved to: " + ReportFileName + ".txt\n";
      
   Print(message);
   MessageBox(message, "Trade Statistics Report", MB_OK | MB_ICONINFORMATION);
}

//+------------------------------------------------------------------+
//| Save report to a file                                            |
//+------------------------------------------------------------------+
void SaveReportToFile(string symbol)
{
   int file = FileOpen(ReportFileName + ".txt", FILE_WRITE | FILE_TXT);
   
   if(file == INVALID_HANDLE)
   {
      Print("Failed to save report file. Error: ", GetLastError());
      return;
   }
   
   // Write report header
   FileWrite(file, "======================================================");
   FileWrite(file, "                TRADING STATISTICS REPORT");
   FileWrite(file, "======================================================");
   FileWrite(file, "");
   FileWrite(file, "Symbol: " + symbol);
   FileWrite(file, "Period: " + TimeToString(Start_Date, TIME_DATE) + " to " + TimeToString(End_Date, TIME_DATE));
   FileWrite(file, "Magic Number: " + (Magic_Number == 0 ? "All" : IntegerToString(Magic_Number)));
   FileWrite(file, "Comment Filter: " + (Comment_Filter == "" ? "All" : Comment_Filter));
   FileWrite(file, "");
   
   // Write trade statistics
   FileWrite(file, "--- TRADE STATISTICS ---");
   FileWrite(file, "Total Trades: " + IntegerToString(totalTrades));
   FileWrite(file, "Winning Trades: " + IntegerToString(winningTrades) + " (" + DoubleToString(winRate, 2) + "%)");
   FileWrite(file, "Losing Trades: " + IntegerToString(losingTrades) + " (" + DoubleToString(100 - winRate, 2) + "%)");
   FileWrite(file, "");
   
   // Write profit/loss statistics
   FileWrite(file, "--- PROFIT/LOSS STATISTICS ---");
   FileWrite(file, "Gross Profit: " + DoubleToString(grossProfit, 2));
   FileWrite(file, "Gross Loss: " + DoubleToString(grossLoss, 2));
   FileWrite(file, "Net Profit: " + DoubleToString(netProfit, 2));
   FileWrite(file, "Profit Factor: " + DoubleToString(profitFactor, 2));
   FileWrite(file, "Max Drawdown: " + DoubleToString(maxDrawdown, 2));
   FileWrite(file, "Average Win: " + DoubleToString(avgWin, 2));
   FileWrite(file, "Average Loss: " + DoubleToString(avgLoss, 2));
   FileWrite(file, "Expectancy: " + DoubleToString(expectancy, 2) + " per trade");
   FileWrite(file, "");
   
   // Write streak statistics
   FileWrite(file, "--- STREAK STATISTICS ---");
   FileWrite(file, "Max Consecutive Wins: " + IntegerToString(maxConsecutiveWins));
   FileWrite(file, "Max Consecutive Losses: " + IntegerToString(maxConsecutiveLosses));
   FileWrite(file, "");
   
   // Write footer
   FileWrite(file, "Report generated on: " + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
   FileWrite(file, "======================================================");
   
   FileClose(file);
   Print("Report saved to file: ", TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + ReportFileName + ".txt");
}