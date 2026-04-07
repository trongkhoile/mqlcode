//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

CTrade trade;
#define PANEL_NAME   "INFO_PANEL"
#define PANEL_X      260
#define PANEL_Y      20
#define PANEL_W      260
#define PANEL_H      260
input double RiskUSD   = 33; // Số tiền risk mỗi lệnh
input double RR = 3;// Tỉ lệ RR để tính TP
input int EMA_8 = 8;
input int EMA_21 = 21;
input int EMA_200 = 200;
input double sar_start = 0.05;
input double sar_inc   = 0.005;
input double sar_max   = 0.2;
input double DailyDD = 3;   // Dừng lỗ ngày(mặc định 3R)
input double WeekDD = 10;   // Dừng lỗ tuần(mặc định 10R)
input double MaxTotalDD = 10.0;  // drawdown tối đa %
input string Time_Order = "01:00:00-5:00:00/5:00:00-7:00:00";// Thời gian chạy Bot
input string BotToken = "8577816937:AAFPSCYCb2pjKJ__74mbMFbTQattCCM1HDY"; // Token
input string ChatID   = "6487663759";                                     // Chat ID 
//================ INPUT =================
double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
double WeeklyClosedPnL = 0;
int CurrentWeek = -1;
int ema8Handle;
int ema21Handle;
int ema200Handle;
int vwapHandle;
int sarHandle;
double DailyClosedPnL = 0;
double TotalClosedPnL = 0;
double StartDayBalance = 0;
double PeakBalance = 0;
datetime lastDealTime = 0;
int CurrentDay = -1;
datetime BotStartTime;
double StartBalance;
int LastReportDay = -1;
double MonthlyClosedPnL = 0;
double YearlyClosedPnL = 0;

int CurrentMonth = -1;
int CurrentYear = -1;
double sar[3];
double af[3];
double ep[3];
bool trendUp[3];

//+------------------------------------------------------------------+
int OnInit()
{
   ObjectsDeleteAll(0,PANEL_NAME);
   Notify("Bot da khoi tao thanh cong");
   BotStartTime = TimeCurrent();
   StartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   CreateLabel("L0",10,clrBlue);
   CreateLabel("L1",40,clrLime);
   CreateLabel("L2",60,clrRed);
   CreateLabel("L3",80,clrWhite);
   CreateLabel("L4",100,clrWhite);
   CreateLabel("L5",120,clrWhite);
   CreateLabel("L6",140,clrWhite);
   StartDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   PeakBalance = StartDayBalance;
   ema8Handle = iMA(_Symbol,_Period,EMA_8,0,MODE_EMA,PRICE_CLOSE);
   ema21Handle = iMA(_Symbol,_Period,EMA_21,0,MODE_EMA,PRICE_CLOSE);
   ema200Handle = iMA(_Symbol,_Period,EMA_200,0,MODE_EMA,PRICE_CLOSE);
   vwapHandle = iCustom(_Symbol,_Period,"Adaptive_VWAP_Institutional");
   sarHandle = iCustom(_Symbol,_Period,"parabolicsar");
   if(vwapHandle == INVALID_HANDLE)
   {
      Print("Cannot load VWAP indicator");
      return(INIT_FAILED);
   }
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
int DaysRunning()
{
   return (int)((TimeCurrent() - BotStartTime) / 86400);
}

string FormatDate(datetime t)
{
   MqlDateTime s;
   TimeToStruct(t,s);
   return StringFormat("%02d/%02d/%04d", s.day, s.mon, s.year);
}

void SendDailyReport()
{
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   double totalPercent = (currentBalance - StartBalance) / StartBalance * 100.0;

   double dailyPercent = (DailyClosedPnL / StartBalance) * 100.0;
   double monthlyPercent = (MonthlyClosedPnL / StartBalance) * 100.0;
   double yearlyPercent  = (YearlyClosedPnL / StartBalance) * 100.0;

   string msg = "Thong tin tai khoan:\n";

   msg += "- ID tai khoan: " + (string)AccountInfoInteger(ACCOUNT_LOGIN) + "\n";
   msg += "- Von ban dau: " + DoubleToString(StartBalance,2) + "\n";
   msg += "- Tong von hien tai: " + DoubleToString(currentBalance,2) +
          " (" + DoubleToString(totalPercent,2) + "%)\n";

   msg += "- Thoi gian chay bot: " 
          + FormatDate(BotStartTime) + " - "
          + FormatDate(TimeCurrent()) + " (" 
          + (string)DaysRunning() + " ngay)\n";

   msg += "- Loi nhuan:\n";
   msg += "  + Ngay: " + DoubleToString(dailyPercent,2) + "%\n";
   msg += "  + Thang: " + DoubleToString(monthlyPercent,2) + "%\n";
   msg += "  + Nam: " + DoubleToString(yearlyPercent,2) + "%\n";

   Notify(msg);
}

double CalculateSAR()
{
   int bars = iBars(_Symbol,_Period);

   if(bars < 2) return 0;

   double high[];
   double low[];

   ArraySetAsSeries(high,false);
   ArraySetAsSeries(low,false);

   CopyHigh(_Symbol,_Period,0,bars,high);
   CopyLow(_Symbol,_Period,0,bars,low);

   double sar[];
   double af[];
   double ep[];
   bool trendUp[];

   ArrayResize(sar,bars);
   ArrayResize(af,bars);
   ArrayResize(ep,bars);
   ArrayResize(trendUp,bars);

   trendUp[0] = true;
   sar[0] = low[0];
   ep[0] = high[0];
   af[0] = sar_start;

   for(int i=1;i<bars;i++)
   {
      sar[i] = sar[i-1] + af[i-1]*(ep[i-1]-sar[i-1]);

      if(trendUp[i-1])
      {
         if(low[i] < sar[i])
         {
            trendUp[i] = false;
            sar[i] = ep[i-1];
            ep[i] = low[i];
            af[i] = sar_start;
         }
         else
         {
            trendUp[i] = true;

            if(high[i] > ep[i-1])
            {
               ep[i] = high[i];
               af[i] = MathMin(af[i-1] + sar_inc, sar_max);
            }
            else
            {
               ep[i] = ep[i-1];
               af[i] = af[i-1];
            }
         }
      }
      else
      {
         if(high[i] > sar[i])
         {
            trendUp[i] = true;
            sar[i] = ep[i-1];
            ep[i] = high[i];
            af[i] = sar_start;
         }
         else
         {
            trendUp[i] = false;

            if(low[i] < ep[i-1])
            {
               ep[i] = low[i];
               af[i] = MathMin(af[i-1] + sar_inc, sar_max);
            }
            else
            {
               ep[i] = ep[i-1];
               af[i] = af[i-1];
            }
         }
      }
   }

   return sar[bars-1];
}

// Gửi Telegram bằng GET URL
bool SendTelegram(string botToken, string chatID, string msg)
 {
   string url = "https://api.telegram.org/bot"+botToken+"/sendMessage?chat_id="+chatID+"&text="+URLEncodeASCII(msg);

   char post[];
   char result[];
   string result_headers;

   ResetLastError();
   int res = WebRequest("GET", url, "", 5000, post, result, result_headers);

   Print("Telegram URL: ", url);
   Print("WebRequest res = ", res, " LastError = ", GetLastError());
   Print("Result body: ", CharArrayToString(result));

   return (res==200);
}
  
void Notify(string msg)
{
   Alert(msg);
   Comment(msg);
   PlaySound("alert.wav");
   if(!SendTelegram(BotToken, ChatID, msg))
      Print("⚠️ Telegram send failed!");
}

string URLEncodeASCII(string msg)
  {
   string enc = "";
   for(int i=0; i<StringLen(msg); i++)
     {
      string c = StringSubstr(msg, i, 1); // lấy ký tự i-th
      ushort code = msg[i];

      if(code>=32 && code<=126)       // ASCII hiển thị
         enc += c;
      else
         if(code=='\n')             // xuống dòng
            enc += "%0A";
         else                             // encode %XX
            enc += "%" + StringFormat("%02X", code & 0xFF);
     }
   return enc;
  }
  
double CalculateVWAP(int shift)
{
   static double CumulativeTPV = 0.0;
   static double CumulativeVolume = 0.0;

   MqlDateTime timeStruct;
   TimeToStruct(iTime(_Symbol,_Period,shift), timeStruct);

   if(shift > 0)
   {
      MqlDateTime prevTimeStruct;
      TimeToStruct(iTime(_Symbol,_Period,shift+1), prevTimeStruct);

      if(timeStruct.day != prevTimeStruct.day)
      {
         CumulativeTPV = 0.0;
         CumulativeVolume = 0.0;
      }
   }

   double high  = iHigh(_Symbol,_Period,shift);
   double low   = iLow(_Symbol,_Period,shift);
   double close = iClose(_Symbol,_Period,shift);

   double typicalPrice = (high + low + close) / 3.0;

   long barVolume = iVolume(_Symbol,_Period,shift);
   if(barVolume <= 1)
      barVolume = 1;

   CumulativeTPV += typicalPrice * barVolume;
   CumulativeVolume += (double)barVolume;

   if(CumulativeVolume != 0)
      return CumulativeTPV / CumulativeVolume;

   return 0.0;
}

bool IsNewBar()
{
   static datetime lastbar=0;
   datetime curbar=iTime(_Symbol,_Period,0);
   if(lastbar!=curbar)
   {
      lastbar=curbar;
      return true;
   }
   return false;
}


double CalculateLot(double entry,double sl,double risk)
{
   double tick_size  = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lot_step   = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double min_lot    = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double max_lot    = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);

   double distance = MathAbs(entry - sl);

   double loss_per_lot = (distance / tick_size) * tick_value;

   double lot = risk / loss_per_lot;

   lot = MathFloor(lot / lot_step) * lot_step;

   if(lot < min_lot) lot = min_lot;
   if(lot > max_lot) lot = max_lot;

   return NormalizeDouble(lot,2);
}
//+------------------------------------------------------------------+

void UpdateClosedPnL()
{
   datetime now = TimeCurrent();

   if(!HistorySelect(now - 86400*30, now))
      return;

   int deals = HistoryDealsTotal();

   for(int i=deals-1;i>=0;i--)
   {
      ulong ticket = HistoryDealGetTicket(i);

      datetime dealTime = (datetime)HistoryDealGetInteger(ticket,DEAL_TIME);

      if(dealTime <= lastDealTime)
         break;

      int type = HistoryDealGetInteger(ticket,DEAL_TYPE);

      if(type == DEAL_TYPE_BUY || type == DEAL_TYPE_SELL)
      {
         double profit = HistoryDealGetDouble(ticket,DEAL_PROFIT);

         DailyClosedPnL += profit;
         WeeklyClosedPnL += profit;
         MonthlyClosedPnL += profit;
         YearlyClosedPnL += profit;
         TotalClosedPnL += profit;

         // cập nhật balance sau khi đóng lệnh
         double balance = AccountInfoDouble(ACCOUNT_BALANCE);

         if(balance > PeakBalance)
            PeakBalance = balance;
      }

      lastDealTime = dealTime;
   }
}

bool CheckDrawdown()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   double maxDD = (PeakBalance - balance) / PeakBalance * 100.0;

   // ===== DAILY LOSS LIMIT =====
   if(DailyClosedPnL <= -(DailyDD * RiskUSD))
   {
      Print("Daily loss limit reached");
      return false;
   }

   // ===== WEEKLY LOSS LIMIT =====
   if(WeeklyClosedPnL <= -(WeekDD * RiskUSD))
   {
      Print("Weekly loss limit reached");
      return false;
   }

   // ===== MAX DRAWDOWN % =====
   if(maxDD >= MaxTotalDD)
   {
      Print("Max DD reached");
      return false;
   }

   return true;
}

void CreateLabel(string name,int y,color clr)
{
   ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,PANEL_X-220);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,PANEL_Y+y);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);
   ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
}

void SetText(string name,string text,color clr)
{
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
}

void UpdatePanel()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

   SetText("L0","===== BOT STATUS =====",clrBlack);
   
   SetText("L1","Balance : "+DoubleToString(balance,2),clrBlack);
   SetText("L2","Equity  : "+DoubleToString(equity,2),clrBlack);
   
   SetText("L3","Daily PnL : "+DoubleToString(DailyClosedPnL,2),
           DailyClosedPnL>=0 ? clrBlack : clrBlack);
   
   SetText("L4","Week PnL : "+DoubleToString(WeeklyClosedPnL,2),
           WeeklyClosedPnL>=0 ? clrBlack : clrBlack);
   
   SetText("L5","Total PnL : "+DoubleToString(TotalClosedPnL,2),
           TotalClosedPnL>=0 ? clrBlack : clrBlack);
   
   double maxDD = (PeakBalance - balance) / PeakBalance * 100.0;
   
   SetText("L6","Max DD : "+DoubleToString(maxDD,2)+" %",
           maxDD>=MaxTotalDD ? clrBlack : clrBlack);
}

void OnTick()
{
   double profit = PositionGetDouble(POSITION_PROFIT);
   long type     = PositionGetInteger(POSITION_TYPE);
   if(profit <= -RiskUSD)
   {
      CTrade trade;
      trade.SetAsyncMode(true);
      Close();
      Print("Cut loss reached: ", profit);
      return;
   }  
   MqlDateTime t;
   TimeToStruct(TimeCurrent(),t);
   // gửi báo cáo lúc 23:59 và chỉ gửi 1 lần/ngày
   if(t.hour == 23 && t.min >= 59)
   {
      if(LastReportDay != t.day)
      {
         SendDailyReport();
         LastReportDay = t.day;
      }
   }
   // ===== RESET MONTH =====
   if(CurrentMonth != t.mon)
   {
      CurrentMonth = t.mon;
      MonthlyClosedPnL = 0;
   }
   
   // ===== RESET YEAR =====
   if(CurrentYear != t.year)
   {
      CurrentYear = t.year;
      YearlyClosedPnL = 0;
   }
   if(CurrentDay != t.day)
   {
      CurrentDay = t.day;
      DailyClosedPnL = 0;
   }
   
   if(CurrentWeek != t.day_of_week)
   {
      CurrentWeek = t.day_of_week;
      if(t.day_of_week == 1) // reset thứ 2
         WeeklyClosedPnL = 0;
   }
   UpdatePanel();
   UpdateClosedPnL();
   if(!CheckDrawdown()){
      return;
   }
   double ema8[2];
   double ema21[2];
   double ema200[2];

   CopyBuffer(ema8Handle,0,0,2,ema8);
   CopyBuffer(ema21Handle,0,0,2,ema21);
   CopyBuffer(ema200Handle,0,0,2,ema200);
   double vwap[];
   CopyBuffer(vwapHandle,0,0,1,vwap);
   double priceAsk = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double priceBid = SymbolInfoDouble(_Symbol,SYMBOL_BID);

   double close = iClose(_Symbol,_Period,1);
   double open  = iOpen(_Symbol,_Period,1);
   if(!IsNewBar()){
      return;
   }
   bool bullish = close > open; // nến xanh
   bool bearish = close < open; // nến đỏ
   double sarBuffer[];
   CopyBuffer(sarHandle,0,0,2,sarBuffer);
   double sar_now = sarBuffer[0];
   double vwapValue = vwap[0];
   bool buySignal =
   close > ema8[0] &&
   ema8[0] > ema21[0] &&
   ema21[0] > vwapValue &&
   ema21[0] > ema200[0] &&
   close > sar_now &&
   bullish;

   bool sellSignal =
   close < ema8[0] &&
   ema8[0] < ema21[0] &&
   ema21[0] < vwapValue &&
   ema21[0] < ema200[0] &&
   close < sar_now &&
   bearish;
   
   if(!HasPositionCurrentSymbol())
   {

      //================ BUY =================
      if(buySignal)
      {
         if(!IsTradingTime())
         {
            return;
         }
         double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)* _Point;
         double sl = priceAsk - (priceAsk-sar_now)*0.618 - spread;
         double tp = priceAsk + (priceAsk-sar_now)*0.618*RR;
         double lot = CalculateLot(priceAsk,sl,RiskUSD);
         if(lot < 0.01){
            return;
         }
         lot = NormalizeDouble(lot,2);
         trade.Buy(lot,_Symbol,priceAsk, 0,tp+spread);
      }

      //================ SELL =================
      if(sellSignal)
      {
         if(!IsTradingTime())
         {
            return;
         }
         double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)* _Point;
         double sl = priceBid + (sar_now-priceBid)*0.618+spread;
         double tp = priceAsk - (sar_now-priceBid)*0.618*RR;
         double lot = CalculateLot(priceBid,sl,RiskUSD);
         if(lot < 0.01){
            return;
         }
         lot = NormalizeDouble(lot,2);
         trade.Sell(lot,_Symbol,priceBid, 0,tp-spread);
      }

   }
   //================ POSITION MANAGEMENT =================
   
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      PositionSelectByTicket(ticket);
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      double profit = PositionGetDouble(POSITION_PROFIT);
      long type     = PositionGetInteger(POSITION_TYPE);
      // ===== EARLY EXIT BUY =====
      if(type == POSITION_TYPE_BUY)
      {
         if(close < ema21[1] && bearish)
         {
            trade.PositionClose(ticket);
            continue;
         }
      }
   
      // ===== EARLY EXIT SELL =====
      if(type == POSITION_TYPE_SELL)
      {
         if(close > ema21[1] && bullish)
         {
            trade.PositionClose(ticket);
            continue;
         }
      }
   }
}

void Close()
{
   CTrade trade;
   trade.SetAsyncMode(true);

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
         trade.PositionClose(ticket);
   }
}

bool HasPositionCurrentSymbol()
{
   for(int i=0;i<PositionsTotal();i++)
   {
      if(PositionGetSymbol(i)==_Symbol)
      {
         return true;
      }
   }
   return false;
}

bool IsTradingTime()
{
   datetime now = TimeCurrent();
   MqlDateTime t;
   TimeToStruct(now,t);

   int current = t.hour*3600 + t.min*60 + t.sec;

   string parts[];
   int count = StringSplit(Time_Order,'/',parts);

   for(int i=0;i<count;i++)
   {
      string range[];
      if(StringSplit(parts[i],'-',range) != 2)
         continue;

      int start = StringToInteger(StringSubstr(range[0],0,2))*3600 +
                  StringToInteger(StringSubstr(range[0],3,2))*60 +
                  StringToInteger(StringSubstr(range[0],6,2));

      int end = StringToInteger(StringSubstr(range[1],0,2))*3600 +
                StringToInteger(StringSubstr(range[1],3,2))*60 +
                StringToInteger(StringSubstr(range[1],6,2));

      if(current >= start && current <= end)
         return true;
   }

   return false;
}

void OnDeinit(const int reason)
{
   ObjectDelete(0,"PANEL_BG");
   ObjectDelete(0,"L0");
   ObjectDelete(0,"L1");
   ObjectDelete(0,"L2");
   ObjectDelete(0,"L3");
   ObjectDelete(0,"L4");
   ObjectDelete(0,"L5");
   ObjectDelete(0,"L6");
}