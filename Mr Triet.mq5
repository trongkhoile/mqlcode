//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

input double StartLot      = 0.01;     // Lot khởi đầu DCA âm
input int    TP_Points     = 5000;     // TP lệnh phần 1 theo point
input double    DCA_Main      = 2000;     // Khoảng cách đến lệnh gốc phần 1
input double    StartLotDA1   = 0.02;     // Lot gốc khởi đầu DCA âm phần 1
input double   DCA_Step      = 1000;     // Khoảng cách DCA âm phần 1
input double Multiplier    = 2.0;      // Hệ số nhân lot DCA âm phần 1
input double StartLotDP1 = 0.01; //Lot gốc khởi đầu DCA dương phần 1
input double DCA_StepDP1 = 1000; // Khoảng cách DCA dương phần 1
input double MultiplierDP1    = 2.0;      // Hệ số nhân lot DCA dương phần 1
input int NumberCloseP1 = 2; // Số lệnh DCA Dương đạt tới thì đóng lệnh đầu
input double ProfitTarget  = 50;       // Đóng toàn bộ khi đạt $ này
input int NumberPositionP1 = 2; //Số lệnh tối đa để sang phần 2
input double LotAmP2 = 0.04;// Lot gốc DCA âm phần 2
input double LotDuongP2 = 0.02;// Lot gốc DCA dương phần 2
input double Dca_Step_Am = 1000;// Khoảng cách nhồi âm phần 2
input double Dca_Step_Duong = 1000;// Khoảng cách nhồi dương phần 2
input double M_Am = 2;// Hệ số nhồi âm phần 2
input double M_Duong = 2;// Hệ số nhồi dương phần 2
input int NumberPP3 = 2;//Số lệnh để qua phần 3
input bool BatTat = true;// Bật tắt phần 3
input double Dca_Step_Am3 = 1000;// Khoảng cách nhồi âm phần 3
input double Dca_Step_Duong3 = 1000;// Khoảng cách nhồi dương phần 3
input double M_Am3 = 2;// Hệ số nhồi âm phần 3
input double M_Duong3 = 2;// Hệ số nhồi dương phần 3
input string ThoiGianBatDau      = "00:01";   // Giờ bắt đầu EA
input string ThoiGianKetThuc     = "21:00";   // Giờ kết thúc EA
double lastDCADuongPrice = 0;
double lotsave = 0;
double lotsaveP2 = 0;
int checkall = 0;
double lastEntryPrice = 0;
double lastEntryPriceP2New = 0;
int    direction = 0; // 1 = Buy, -1 = Sell
bool isPhase2 = false;
double lastEntryPriceP2 = 0;
int directionP2 = 0; // 1 buy -1 sell
double lastPriceStep = 0;
bool firstSellOpened = false;
double lastBuyPriceStep = 0;
bool firstBuyOpened = false;
int tong = 0;
//+------------------------------------------------------------------+
void OnTick()
{
   CheckProfitClose();
   CloseIfSingleDCADuong();
   if(checkall == 1){
      CloseAll();
   }
   bool trongGio = CheckTradingTime();
   if(PositionsTotal()==0 && trongGio)
   {
      CheckNewSignal();
      tong = 0;
      isPhase2 = false;
      return;
   }
   else
   {
      ManageDCA();
      if(isPhase2== true && tong < NumberPP3){
         if (direction == 1){
            SellEvery1000Points();
         }
         else{
            BuyEvery1000Points();
         }
      }
      if(BatTat == true && tong >=NumberPP3){
         if (direction == 1){
            SellEvery1000Points3();
         }
         else{
            BuyEvery1000Points3();
         }
      }
   }
}
//+------------------------------------------------------------------+
void CloseIfSingleDCADuong()
{
   int totalPositions = PositionsTotal();

   // Nếu không phải chỉ có 1 lệnh thì thoát
   if(totalPositions != 1)
      return;

   ulong ticket = PositionGetTicket(0);
   if(ticket == 0)
      return;

   if(PositionSelectByTicket(ticket))
   {
      string symbol  = PositionGetString(POSITION_SYMBOL);
      string comment = PositionGetString(POSITION_COMMENT);

      // Kiểm tra đúng symbol và đúng comment
      if(symbol == _Symbol && comment == "DCA_DUONG")
      {
         CloseAll();
      }
   }
}

void CheckNewSignal()
{
   double open1 = iOpen(_Symbol, PERIOD_M1, 1);
   double close1 = iClose(_Symbol, PERIOD_M1, 1);

   if(close1 > open1) direction = 1;
   else if(close1 < open1) direction = -1;
   else return;

   double lot = StartLot;
   double price,tp;

   if(direction == 1)
   {
      price = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      tp = price + TP_Points * _Point;
      trade.Buy(lot,_Symbol,price,0,tp,"");
      checkall = 0;
   }
   else
   {
      price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      tp = price - TP_Points * _Point;
      trade.Sell(lot,_Symbol,price,0,tp,"");
      checkall = 0;
   }

   lastEntryPrice = price;
}
//+------------------------------------------------------------------+

void ManageDCA()
{
   int totalPositions = CountPositions();
   // =====================
   // PHẦN 1
   // =====================
   if(!isPhase2)
   {
      CheckAddDCADuong();
      CloseOldestDCADuongIfThree();
      if(totalPositions >= NumberPositionP1)
      {
         
         Print("Chuyển sang PHASE 2");
         isPhase2 = true;

         // tạo lệnh gốc mới cho phase 2
         directionP2 = direction;
         lastEntryPriceP2 = lastEntryPrice;
         lastPriceStep = lastEntryPrice;
         lastBuyPriceStep = lastEntryPrice;
         return;
      }

      // DCA PHẦN 1 như cũ
      double currentPrice = (direction==1)?
         SymbolInfoDouble(_Symbol,SYMBOL_BID):
         SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double nextLot = StartLot * MathPow(Multiplier,totalPositions);
      
      if(direction == 1)
      {
         if(CountPositions() == 0 && currentPrice <= lastEntryPrice - DCA_Main*_Point){
            RemoveFirstTP();
            BuyAsync(StartLotDA1,"DCA_AM");
            trade.Sell(StartLotDP1,_Symbol,bid,0,0,"DCA_DUONG");
            lastEntryPrice = currentPrice;
            lastDCADuongPrice = bid;
            lotsave = StartLotDP1;
         }
         if(CountPositions() != 0 && currentPrice <= lastEntryPrice - DCA_Step*_Point){
            RemoveFirstTP();
            double lot = StartLotDA1 * MathPow(Multiplier,CountBuyPositions1());
            BuyAsync(lot,"DCA_AM");
            lastEntryPrice = currentPrice;
         }
      }

      if(direction == -1)
      {
         if(CountPositions() == 0 && currentPrice >= lastEntryPrice + DCA_Main*_Point){
            RemoveFirstTP();
            SellAsync(StartLotDA1,"DCA_AM");
            trade.Buy(StartLotDP1,_Symbol,ask,0,0,"DCA_DUONG");
            lastEntryPrice = currentPrice;
            lastDCADuongPrice = ask;
            lotsave =StartLotDP1;
         }
         if(CountPositions() != 0 && currentPrice >= lastEntryPrice + DCA_Step*_Point){
            RemoveFirstTP();
            double lot = StartLotDA1 * MathPow(Multiplier,CountSellPositions1());
            SellAsync(lot,"DCA_AM");
            lastEntryPrice = currentPrice;
         }
      }

      return;
   }

   // =====================
   // PHẦN 2
   // =====================

   double currentPrice = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(directionP2 == 1)
   {
      // DCA ÂM (giá giảm)
      if(currentPrice <= lastEntryPriceP2 - Dca_Step_Am*_Point)
      {
         double lot = LotAmP2 * MathPow(Multiplier,CountBuyPositions());
         if(BatTat == true && tong >= NumberPP3){
            lot = lotsaveP2*M_Am3;
         }
         lotsaveP2 = lot;
         BuyAsync(lot,"DCA_AM_P2");
         tong += 1;
         lastEntryPriceP2 = currentPrice;
      }
   }
   else
   {
      // DCA ÂM (giá tăng)
      if(currentPrice >= lastEntryPriceP2 + Dca_Step_Am*_Point)
      {
         double lot = LotAmP2 * MathPow(M_Am,CountSellPositions());
         if(BatTat == true && tong >= NumberPP3){
            Print(CountSellPositions());
            lot = lotsaveP2*M_Am3;
         }
         lotsaveP2 = lot;
         SellAsync(lot,"DCA_AM_P2");
         tong += 1;
         lastEntryPriceP2 = currentPrice;
      }
   }
}
//+------------------------------------------------------------------+

void CheckProfitClose()
{
   double totalProfit = 0;

   for(int i=0;i<PositionsTotal();i++)
   {
      if(PositionGetTicket(i)>0)
      {
         totalProfit += PositionGetDouble(POSITION_PROFIT);
      }
   }

   if(totalProfit >= ProfitTarget)
   {
      CloseAll();
      checkall = 1;
      lastDCADuongPrice == 0;
   }
}
//+------------------------------------------------------------------+

int CountPositions()
{
   int count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      
      if(ticket > 0)
      {
         if(PositionSelectByTicket(ticket))
         {
            string comment = PositionGetString(POSITION_COMMENT);
            
            if(comment == "DCA_AM")
            {
               count++;
            }
         }
      }
   }

   return count;
}
//+------------------------------------------------------------------+

void CloseAll()
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
   firstSellOpened = false;
   firstBuyOpened = false;
}

void RemoveFirstTP()
{
   ulong oldestTicket = 0;
   datetime oldestTime = LONG_MAX;

   // 🔎 Tìm lệnh DCA_AM mở sớm nhất
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

            if(openTime < oldestTime)
            {
               oldestTime = openTime;
               oldestTicket = ticket;
            }
         }
      }
   }

   // 🎯 Nếu tìm được lệnh
   if(oldestTicket > 0 && PositionSelectByTicket(oldestTicket))
   {
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);

      // ✅ Chỉ modify nếu TP đang khác 0
      if(tp != 0)
      {
         if(!trade.PositionModify(oldestTicket, sl, 0))
         {
            Print("Lỗi remove TP DCA_AM: ", GetLastError());
         }
         else
         {
            Print("Đã xóa TP của DCA_AM cũ nhất. Ticket: ", oldestTicket);
         }
      }
   }
}


void SellEvery1000Points()
{
   if (BatTat == true && tong >=NumberPP3){
      return;
   }
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   // Nếu chưa có lệnh SELL nào
   if(!firstSellOpened && bid <= lastPriceStep - Dca_Step_Duong * _Point)
   {
      trade.Sell(LotDuongP2);
      lastPriceStep = bid;
      firstSellOpened = true;
      Print("Mở SELL đầu tiên 0.04 lot");
      return;
   }

   // Nếu giá giảm thêm 1000 point so với lệnh SELL gần nhất
   if(bid <= lastPriceStep - Dca_Step_Duong * _Point)
   {
      double lastLot = GetLastSellLot();
      double nextLot = lastLot * M_Duong;

      SellAsync(nextLot,"DCA_DUONG_P2");
      lastPriceStep = bid;

      Print("Mở SELL nhân lot: ", nextLot);
   }
}

void BuyEvery1000Points()
{
   if (BatTat == true && tong >=NumberPP3){
      return;
   }
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Nếu chưa có BUY nào
   if(!firstBuyOpened && ask >= lastBuyPriceStep + Dca_Step_Duong * _Point)
   {
      trade.Buy(LotDuongP2);
      lastBuyPriceStep = ask;
      firstBuyOpened = true;
      Print("Mở BUY đầu tiên 0.04 lot");
      return;
   }

   // Nếu giá giảm thêm 1000 point so với lệnh BUY gần nhất
   if(ask >= lastBuyPriceStep + Dca_Step_Duong * _Point)
   {
      double lastLot = GetLastBuyLot();
      double nextLot = lastLot * M_Duong;

      BuyAsync(nextLot,"DCA_DUONG_P2");
      lastBuyPriceStep = ask;

      Print("Mở BUY nhân lot: ", nextLot);
   }
}

void SellEvery1000Points3()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   // Nếu chưa có lệnh SELL nào
   if(!firstSellOpened && bid <= lastPriceStep - Dca_Step_Duong3 * _Point)
   {
      trade.Sell(LotDuongP2);
      lastPriceStep = bid;
      firstSellOpened = true;

      Print("Mở SELL đầu tiên 0.04 lot");
      return;
   }

   // Nếu giá giảm thêm 1000 point so với lệnh SELL gần nhất
   if(bid <= lastPriceStep - Dca_Step_Duong3 * _Point)
   {
      double lastLot = GetLastSellLot();
      double nextLot = lastLot * M_Duong3;
      SellAsync(nextLot,"DCA_DUONG_P3");

      lastPriceStep = bid;
   
      Print("Mở SELL nhân lot: ", nextLot);
   }
}

void BuyEvery1000Points3()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Nếu chưa có BUY nào
   if(!firstBuyOpened && ask >= lastBuyPriceStep + Dca_Step_Duong3 * _Point)
   {
      trade.Buy(LotDuongP2);
      lastBuyPriceStep = ask;
      firstBuyOpened = true;

      Print("Mở BUY đầu tiên 0.04 lot");
      return;
   }

   // Nếu giá giảm thêm 1000 point so với lệnh BUY gần nhất
   if(ask >= lastBuyPriceStep + Dca_Step_Duong3 * _Point)
   {
      double lastLot = GetLastBuyLot();
      double nextLot = lastLot * M_Duong3;

      BuyAsync(nextLot,"DCA_DUONG_P3");

      lastBuyPriceStep = ask;

      Print("Mở BUY nhân lot: ", nextLot);
   }
}

double GetLastBuyLot()
{
   double lastLot = 0;
   datetime lastTime = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
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
   double lastLot = 0;
   datetime lastTime = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
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
   req.deviation   =10;
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
   req.deviation   =10;
   req.comment     =cmt;
   MqlTradeResult  res={};
   if(!OrderSendAsync(req,res))
     {
      Print(__FUNCTION__,": error ",GetLastError(),", retcode = ",res.retcode);
     }
//---
  }

int CountBuyPositions()
{
   int count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY &&
            PositionGetString(POSITION_COMMENT) == "DCA_AM_P2")
         {
            count++;
         }
      }
   }

   return count;
}

int CountSellPositions()
{
   int count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && PositionGetString(POSITION_COMMENT) == "DCA_AM_P2")
         {
            count++;
         }
      }
   }

   return count;
}  

int CountBuyPositions1()
{
   int count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY &&
            PositionGetString(POSITION_COMMENT) == "DCA_AM")
         {
            count++;
         }
      }
   }

   return count;
}

int CountSellPositions1()
{
   int count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && PositionGetString(POSITION_COMMENT) == "DCA_AM")
         {
            count++;
         }
      }
   }

   return count;
}  

bool GetLastDCADuong(double &last_price, double &last_lot, int &type)
{
   datetime last_time = 0;
   bool found = false;

   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket>0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
            PositionGetString(POSITION_COMMENT)=="DCA_DUONG")
         {
            datetime opentime=(datetime)PositionGetInteger(POSITION_TIME);

            if(opentime>last_time)
            {
               last_time  = opentime;
               last_price = PositionGetDouble(POSITION_PRICE_OPEN);
               last_lot   = PositionGetDouble(POSITION_VOLUME);
               type       = (int)PositionGetInteger(POSITION_TYPE);
               found = true;
            }
         }
      }
   }

   return found;
}

int CountDCADuong()
{
   int count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetString(POSITION_COMMENT) == "DCA_DUONG")
         {
            count++;
         }
      }
   }

   return count;
}

bool GetLastPosition(double &last_price, double &last_lot, int &type)
{
   datetime last_time = 0;
   bool found = false;

   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL)==_Symbol)
         {
            datetime opentime = (datetime)PositionGetInteger(POSITION_TIME);

            if(opentime > last_time)
            {
               last_time  = opentime;
               last_price = PositionGetDouble(POSITION_PRICE_OPEN);
               last_lot   = PositionGetDouble(POSITION_VOLUME);
               type       = (int)PositionGetInteger(POSITION_TYPE);
               found = true;
            }
         }
      }
   }

   return found;
}
void CheckAddDCADuong()
{
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   double step = DCA_StepDP1 * _Point;

   double last_price,last_lot;
   int type;
   double lot;
   // Nếu chưa có DCA_DUONG → lấy lệnh mới nhất làm mốc
   if(CountDCADuong()==0)
   {
      return; // chờ giá đi đủ step rồi mới vào
   }

   // ===== Nếu BUY gốc → giá giảm thì SELL =====
   if(direction == 1)
   {
      if(bid <= lastDCADuongPrice - step)
      {
         if(CountDCADuong() == 0){
            lot = StartLotDP1;
            lotsave = lot;
         }
         else{
            lot = lotsave*MultiplierDP1;   
            lot = NormalizeDouble(lot, 2);
            lotsave = lot;
         }
         trade.Sell(lot,_Symbol,bid,0,0,"DCA_DUONG");

         lastDCADuongPrice = bid; // cập nhật mốc
      }
   }

   // ===== Nếu SELL gốc → giá tăng thì BUY =====
   if(direction == -1)
   {
      if(ask >= lastDCADuongPrice + step)
      {
         if(CountDCADuong() == 0){ 
            lot = StartLotDP1;
            lotsave = lot;
         }
         else{
            lot = lotsave*MultiplierDP1;   
            lot = NormalizeDouble(lot, 2);
            lotsave = lot;
         }
         trade.Buy(lot,_Symbol,ask,0,0,"DCA_DUONG");

         lastDCADuongPrice = ask;
      }
   }
}
void CloseOldestDCADuongIfThree()
{
   int count = 0;
   ulong oldestTicket = 0;
   datetime oldestTime = LONG_MAX;

   // Đếm và tìm lệnh DCA_DUONG mở sớm nhất
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetString(POSITION_COMMENT) == "DCA_DUONG")
         {
            count++;

            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

            if(openTime < oldestTime)
            {
               oldestTime = openTime;
               oldestTicket = ticket;
            }
         }
      }
   }

   // Nếu đúng 3 lệnh → đóng lệnh cũ nhất
   if(count == NumberCloseP1 && oldestTicket > 0)
   {
      if(trade.PositionClose(oldestTicket))
      {
         Print("Đã đóng DCA_DUONG cũ nhất. Ticket: ", oldestTicket);
      }
      else
      {
         Print("Lỗi đóng lệnh DCA_DUONG: ", GetLastError());
      }
   }
}

bool CheckTradingTime()
{
   if(ThoiGianBatDau=="00:00" && ThoiGianKetThuc=="00:00")
      return true;

   string curDate = TimeToString(TimeCurrent(), TIME_DATE);
   datetime startTime = StringToTime(curDate + " " + ThoiGianBatDau);
   datetime endTime   = StringToTime(curDate + " " + ThoiGianKetThuc);

   if(startTime > endTime)
      return (TimeCurrent() >= startTime || TimeCurrent() <= endTime);
   else
      return (TimeCurrent() >= startTime && TimeCurrent() <= endTime);
}
