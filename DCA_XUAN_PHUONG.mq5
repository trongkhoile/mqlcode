#include <Trade/Trade.mqh>
CTrade trade;

input double Lot = 0.01;//Lot_Trade
input double Multiplier = 2;//Lot_multiple
input double StepPip = 50;//Step_pip
input int MaxOrders = 5;//Number_Trade
input double MaxLot = 5.0;//Gap_Buy_Sell
input int    TotalProfitTarget = 4;// Profit_usd
input double ProfitDayTarget = 50; // Profit_per_day
input double MaxLossCut = 50; // Loss_usd_cut_all
input bool Close_Order_Break_Time = true; //Close_Order_Break_Time
input int  Delay_Seconds_Close = 10;

input string Time_Order = "01:00:00-5:00:00/5:00:00-7:00:00";
input int f_size = 9;
bool StopTradeToday = false;
double lastBuyPrice = 0;
double lastSellPrice = 0;
double ProfitDay = 0;
double ProfitWeek = 0;
double ProfitMonth = 0;
double MaxDD_Day=0;
double MaxDD_Week=0;
double MaxDD_Month=0;
double PeakEquityDay=0;
double PeakEquityWeek=0;
double PeakEquityMonth=0;
int lastDay = -1;
int lastWeek = -1;
int lastMonth = -1;
double currentBuyLot;
double currentSellLot;
double Real_lot;
//================ PANEL PRO =================
#define PANEL_BG "PANEL_BG"

double dayProfit=0;
double weekProfit=0;
double monthProfit=0;

void CreatePanelPro()
{
   ObjectSetInteger(0,PANEL_BG,OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,PANEL_BG,OBJPROP_YDISTANCE,20);
   ObjectSetInteger(0,PANEL_BG,OBJPROP_XSIZE,250);
   ObjectSetInteger(0,PANEL_BG,OBJPROP_YSIZE,220);
   ObjectSetInteger(0,PANEL_BG,OBJPROP_BGCOLOR,clrBlack);
   ObjectSetInteger(0,PANEL_BG,OBJPROP_COLOR,clrAqua);

   CreateLabelPanel("P1",30);
   CreateLabelPanel("P2",45);

   CreateLabelPanel("P6",65);
   CreateLabelPanel("P7",80);
   CreateLabelPanel("P8",95);
   CreateLabelPanel("P9",110);
   CreateLabelPanel("P10",125);
   CreateLabelPanel("P11",140);
   CreateLabelPanel("P12",155);
}

void CreateLabelPanel(string name,int y)
{
   ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,200);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrYellow);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,f_size);
   ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
}

void UpdatePanelPro()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double floating = equity - balance;

   int spread = (int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);

   ObjectSetString(0,"P1",OBJPROP_TEXT,"Balance : "+DoubleToString(balance,2));
   ObjectSetString(0,"P2",OBJPROP_TEXT,"Equity  : "+DoubleToString(equity,2));
   ObjectSetString(0,"P6",OBJPROP_TEXT,"------ PROFIT ------");
   
   ObjectSetString(0,"P7",OBJPROP_TEXT,
   "Day   : "+DoubleToString(ProfitDay,2));
   
   ObjectSetString(0,"P8",OBJPROP_TEXT,
   "Week  : "+DoubleToString(ProfitWeek,2));
   
   ObjectSetString(0,"P9",OBJPROP_TEXT,
   "Month : "+DoubleToString(ProfitMonth,2));
   ObjectSetString(0,"P10",OBJPROP_TEXT,
   "DD Day : "+DoubleToString(MaxDD_Day,2));
   
   ObjectSetString(0,"P11",OBJPROP_TEXT,
   "DD Week: "+DoubleToString(MaxDD_Week,2));
   
   ObjectSetString(0,"P12",OBJPROP_TEXT,
   "DD Month:"+DoubleToString(MaxDD_Month,2));
}

void UpdateDrawdownStats()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(),tm);

   // reset khi sang ngày mới
   if(tm.day != lastDay)
   {
      MaxDD_Day = 0;
      PeakEquityDay = equity;
      lastDay = tm.day;
   }

   // reset khi sang tuần mới
   if(tm.day_of_week == 1 && tm.day != lastWeek)
   {
      MaxDD_Week = 0;
      PeakEquityWeek = equity;
      lastWeek = tm.day;
   }

   // reset khi sang tháng mới
   if(tm.mon != lastMonth)
   {
      MaxDD_Month = 0;
      PeakEquityMonth = equity;
      lastMonth = tm.mon;
   }

   // update peak
   if(equity > PeakEquityDay) PeakEquityDay = equity;
   if(equity > PeakEquityWeek) PeakEquityWeek = equity;
   if(equity > PeakEquityMonth) PeakEquityMonth = equity;

   double ddDay = PeakEquityDay - equity;
   double ddWeek = PeakEquityWeek - equity;
   double ddMonth = PeakEquityMonth - equity;

   if(ddDay > MaxDD_Day) MaxDD_Day = ddDay;
   if(ddWeek > MaxDD_Week) MaxDD_Week = ddWeek;
   if(ddMonth > MaxDD_Month) MaxDD_Month = ddMonth;
}

void UpdateProfitStats()
{
   ProfitDay = 0;
   ProfitWeek = 0;
   ProfitMonth = 0;

   datetime now = TimeCurrent();
   static int lastDay=-1;
   
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(),tm);
   
   if(tm.day != lastDay)
   {
      StopTradeToday=false;
      lastDay = tm.day;
   }

   tm.hour = 0;
   tm.min = 0;
   tm.sec = 0;

   datetime day_start = StructToTime(tm);

   int dow = tm.day_of_week;
   datetime week_start = day_start - dow * 86400;

   tm.day = 1;
   datetime month_start = StructToTime(tm);

   HistorySelect(0, TimeCurrent());

   int total = HistoryDealsTotal();

   for(int i=0;i<total;i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket==0) continue;

      int entry = (int)HistoryDealGetInteger(ticket,DEAL_ENTRY);

      if(entry != DEAL_ENTRY_OUT)
         continue;

      datetime deal_time = (datetime)HistoryDealGetInteger(ticket,DEAL_TIME);

      double profit = HistoryDealGetDouble(ticket,DEAL_PROFIT)
                    + HistoryDealGetDouble(ticket,DEAL_SWAP)
                    + HistoryDealGetDouble(ticket,DEAL_COMMISSION);

      if(deal_time >= day_start)
         ProfitDay += profit;

      if(deal_time >= week_start)
         ProfitWeek += profit;

      if(deal_time >= month_start)
         ProfitMonth += profit;
   }
}

int OnInit()
{
   CreatePanelPro();
   currentBuyLot = Lot;
   currentSellLot = Lot;
   return(INIT_SUCCEEDED);
}
void OnTick()
{
      // kiểm tra giờ trade
   UpdateProfitStats();
   UpdateDrawdownStats();
   UpdatePanelPro();
   if(ProfitDay >= ProfitDayTarget)
   {
      StopTradeToday = true;
      Close();
   }
   if(TotalFloatingProfit() <= -MaxLossCut)
   {
      Print("Dat muc lo -> dong tat ca lenh");
      Close();
      Sleep(Delay_Seconds_Close*1000);
      return;
   }
   if(TotalFloatingProfit() >= TotalProfitTarget){
      Close();
      Sleep(Delay_Seconds_Close*1000);
   }
   if(StopTradeToday)
      return;
   if(!IsTradingTime())
   {
      if(Close_Order_Break_Time)
      {
         Close();
         Sleep(Delay_Seconds_Close*1000);
      }
   }
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // nếu chưa có lệnh nào
   if(PositionsTotal() == 0)
   {
      if(!IsTradingTime())
      {
         return;
      }
      trade.Buy(Lot,_Symbol,0,0,0);
      trade.Sell(Lot,_Symbol,0,0,0);

      lastBuyPrice = ask;
      lastSellPrice = bid;
      currentBuyLot = Lot;
      currentSellLot = Lot;
      return;
   }

   double step = StepPip/10;

   // giá đi lên → mở thêm
   if(ask >= lastBuyPrice + step && CountBuyOrders()-CountSellOrders() < MaxOrders)
   {
      double lastLot = GetLastBuyLot();
      Real_lot = NormalizeDouble(lastLot * Multiplier,2);
      if(Real_lot > MaxLot){
         Real_lot = MaxLot;
      }
      BuyAsync(Real_lot, "");
      lastBuyPrice = ask;
      Print("Gia tang - mo BUY SELL moi");
   }

   // giá đi xuống → mở thêm
   if(bid <= lastSellPrice - step && CountSellOrders() - CountBuyOrders() < MaxOrders)
   {
      double lastLot = GetLastSellLot();
      Real_lot = NormalizeDouble(lastLot * Multiplier,2);
      if(Real_lot > MaxLot){
         Real_lot = MaxLot;
      }
      SellAsync(Real_lot, "");
      lastSellPrice = bid;

      Print("Gia giam - mo BUY SELL moi");
   }
}

int CountSellOrders()
{
   int count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetTicket(i))
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol)
               count++;
         }
      }
   }

   return count;
}

int CountBuyOrders()
{
   int count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetTicket(i))
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol)
               count++;
         }
      }
   }

   return count;
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
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
         trade.OrderDelete(ticket);
   }
}

double TotalFloatingProfit()
{
    double total = 0.0;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        // lấy ticket theo index
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;

        // select lại bằng ticket
        if(PositionSelectByTicket(ticket))
        {
            total += PositionGetDouble(POSITION_PROFIT);
        }
    }

    return total;
    
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

double GetLastBuyLot()
{
   double lastLot = Lot;
   datetime lastTime = 0;

   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
            PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
         {
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

            if(openTime > lastTime)
            {
               lastTime = openTime;
               lastLot = PositionGetDouble(POSITION_VOLUME);
            }
         }
      }
   }

   return lastLot;
}

double GetLastSellLot()
{
   double lastLot = Lot;
   datetime lastTime = 0;

   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
            PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
         {
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

            if(openTime > lastTime)
            {
               lastTime = openTime;
               lastLot = PositionGetDouble(POSITION_VOLUME);
            }
         }
      }
   }

   return lastLot;
}

void BuyAsync(double nextLot, string cmt)
  {
//--- prepare the request
   MqlTradeRequest req={};
   req.action      =TRADE_ACTION_DEAL;
   req.symbol      =_Symbol;
   req.volume      =NormalizeDouble(nextLot, 2);
   req.type        =ORDER_TYPE_BUY;
   req.price       =SymbolInfoDouble(req.symbol,SYMBOL_ASK);
   req.deviation   =50;
   req.comment     =cmt;
   MqlTradeResult  res={};
   if(!OrderSendAsync(req,res))
     {
      Print(__FUNCTION__,": error ",GetLastError(),", retcode = ",res.retcode);
     }
//---
  }
//+------------------------------------------------------------------+
//| Sell using OrderSendAsync() asynchronous function                |
//+------------------------------------------------------------------+
void SellAsync(double nextLot, string cmt)
  {
//--- prepare the request
   MqlTradeRequest req={};
   req.action      =TRADE_ACTION_DEAL;
   req.symbol      =_Symbol;
   req.volume      =NormalizeDouble(nextLot, 2);
   req.type        =ORDER_TYPE_SELL;
   req.price       =SymbolInfoDouble(req.symbol,SYMBOL_BID);
   req.deviation   =50;
   req.comment     =cmt;
   MqlTradeResult  res={};
   if(!OrderSendAsync(req,res))
     {
      Print(__FUNCTION__,": error ",GetLastError(),", retcode = ",res.retcode);
     }
//---
  }