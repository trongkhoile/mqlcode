//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

input double StartLot      = 0.01;     // Lot khởi đầu phần 1
input int    TP_Points     = 5000;     // TP lệnh phần 1 theo point
input int    DCA_Step      = 1000;     // Khoảng cách DCA âm phần 1 (point)
input double Multiplier    = 2.0;      // Hệ số nhân lot phần 1
input double ProfitTarget  = 50;       // Đóng toàn bộ khi đạt $ này
input int NumberPositionP1 = 2; //Số lệnh tối đa để sang phần 2
input double LotAmP2 = 0.04;// Lot gốc DCA âm phần 2
input double LotDuongP2 = 0.02;// Lot gốc DCA dương phần 2
input double Dca_Step_Am = 1000;// Khoảng cách nhồi âm phần 2
input double Dca_Step_Duong = 1000;// Khoảng cách nhồi dương phần 2
input double M_Am = 2;// Hệ số nhồi âm phần 2
input double M_Duong = 2;// Hệ số nhồi dương phần 2
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
//+------------------------------------------------------------------+
void OnTick()
{
   if(PositionsTotal()==0)
   {
      isPhase2 = false;
      CheckNewSignal();
   }
   else
   {
      ManageDCA();
      if(isPhase2== true){
         if (direction == 1){
            SellEvery1000Points();
         }
         else{
            BuyEvery1000Points();
         }
      }
      CheckProfitClose();
   }
}
//+------------------------------------------------------------------+

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
      trade.Buy(lot,_Symbol,price,0,tp,"First Buy");
   }
   else
   {
      price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      tp = price - TP_Points * _Point;
      trade.Sell(lot,_Symbol,price,0,tp,"First Sell");
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

      double nextLot = StartLot * MathPow(Multiplier,totalPositions);

      if(direction == 1 &&
         currentPrice <= lastEntryPrice - DCA_Step*_Point)
      {
         RemoveFirstTP();
         BuyAsync(nextLot);
         lastEntryPrice = currentPrice;
      }

      if(direction == -1 &&
         currentPrice >= lastEntryPrice + DCA_Step*_Point)
      {
         RemoveFirstTP();
         SellAsync(nextLot);
         lastEntryPrice = currentPrice;
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
         double lot = LotAmP2 * MathPow(M_Am,CountBuyPositions()-NumberPositionP1);;
         BuyAsync(lot);
         lastEntryPriceP2 = currentPrice;
      }
   }
   else
   {
      // DCA ÂM (giá tăng)
      if(currentPrice >= lastEntryPriceP2 + Dca_Step_Am*_Point)
      {
         double lot = LotAmP2 * MathPow(M_Am,CountSellPositions()-NumberPositionP1);;
         SellAsync(lot);
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
   }
}
//+------------------------------------------------------------------+

int CountPositions()
{
   int count=0;
   for(int i=0;i<PositionsTotal();i++)
   {
      if(PositionGetTicket(i)>0)
         count++;
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
   ulong firstTicket = 0;
   datetime firstTime = LONG_MAX;

   // Tìm lệnh mở sớm nhất
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

            if(openTime < firstTime)
            {
               firstTime = openTime;
               firstTicket = ticket;
            }
         }
      }
   }

   // Nếu tìm được lệnh đầu
   if(firstTicket > 0 && PositionSelectByTicket(firstTicket))
   {
      double sl = PositionGetDouble(POSITION_SL);

      // Xóa TP bằng cách set TP = 0
      trade.PositionModify(firstTicket, sl, 0);

      Print("Đã xóa TP lệnh đầu tiên. Ticket: ", firstTicket);
   }
}

void SellEvery1000Points()
{
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

      SellAsync(nextLot);

      lastPriceStep = bid;

      Print("Mở SELL nhân lot: ", nextLot);
   }
}

void BuyEvery1000Points()
{
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

      BuyAsync(nextLot);

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
void BuyAsync(double nextLot)
  {
//--- prepare the request
   MqlTradeRequest req={};
   req.action      =TRADE_ACTION_DEAL;
   req.symbol      =_Symbol;
   req.volume      =NormalizeDouble(nextLot, 2);
   req.type        =ORDER_TYPE_BUY;
   req.price       =SymbolInfoDouble(req.symbol,SYMBOL_ASK);
   req.deviation   =10;
   req.comment     ="Buy using OrderSendAsync()";
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
void SellAsync(double nextLot)
  {
//--- prepare the request
   MqlTradeRequest req={};
   req.action      =TRADE_ACTION_DEAL;
   req.symbol      =_Symbol;
   req.volume      =NormalizeDouble(nextLot, 2);
   req.type        =ORDER_TYPE_SELL;
   req.price       =SymbolInfoDouble(req.symbol,SYMBOL_BID);
   req.deviation   =10;
   req.comment     ="Sell using OrderSendAsync()";
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
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
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
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            count++;
         }
      }
   }

   return count;
}  