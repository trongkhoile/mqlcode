#property strict
#include <Trade/Trade.mqh>

CTrade trade;

input double BaseLot    = 0.01; //Lot lệnh gốc đã có
input double Multiple   = 2.0;// Hệ số nhân
input int    Distance   = 300;  //Khoảng cách theo giá
input int    TotalStopsBuy = 4; // Số lệnh Buy Stop tối đa
input int    TotalStopsSell = 4;// Số lệnh Sell Stop tối đa
input int    TotalProfitTarget = 4;// Lợi nhuận thì đóng hết lệnh
input int    BuyStopP2 = 2;//Số lệnh Buy Stop mở thêm phần 2
input int    SellStopP2 = 2;//Số lệnh Sell Stop mở thêm phần 2
input double    MultipleP2 = 2;//Hệ số nhân phần 2
input double    DistanceP2 = 300;//Khoảng cách phần 2
input bool    OnOff = true; //Bật/tắt đóng lệnh khi đi hết lệnh
input int    Timestart = 23;// Giờ bắt đầu chạy Bot
input int    Timeend = 4;// Giờ bắt đầu tắt Bot
bool placed = false;
int check = 0;
// Đếm lệnh đang mở trên symbol hiện tại
int CountPositionsBySymbol()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            count++;
      }
   }
   return count;
}

void OnTick()
{
   if(PositionsTotal() == 0){
      check = 0;
   }
   if(CountBuyPositions() == TotalStopsBuy+1 && CountSellPositions() == TotalStopsSell+1 && check == 0){
      OpenSellStopBelowLastSell(DistanceP2,MultipleP2,SellStopP2);
      OpenBuyStopAboveLastBuy(DistanceP2,MultipleP2,BuyStopP2);
      check = 1;
   }
   if(CountBuyPositions() == TotalStopsBuy+BuyStopP2+1 && CountSellPositions() == TotalStopsSell+SellStopP2+1 && OnOff == true)
   {
      Print("Max BUY & SELL reached → Close all");
      Close();
      check = 0;
   }
   if(TotalFloatingProfit() >= TotalProfitTarget){
      Close();
      check = 0;
   }
   if(!IsTradingTimeVN()){ 
      if(PositionsTotal() == 1){
         Close();
         check = 0;
      }
   }
   if(CountPositionsBySymbol() > 0)
      return;

   // Mở BUY
   if(!IsTradingTimeVN()){ 
      return;
   }
   if(!trade.Buy(BaseLot, _Symbol))
      Print("Buy error: ", trade.ResultRetcodeDescription());
   //}
   PlaceBuyStopDCA(BaseLot, Multiple, TotalStopsBuy, Distance);
   // Mở SELL
   //if(IsTradingTimeVN()){ 
   if(!trade.Sell(BaseLot, _Symbol))
      Print("Sell error: ", trade.ResultRetcodeDescription());
   //}
   PlaceSellStopDCA(BaseLot, Multiple, TotalStopsSell, Distance);
}

void PlaceBuyStopDCA(double baseLot, double multiple, int totalStops, int distancePoint)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // lot buy stop đầu tiên = lot gốc × multiple
   double lot = baseLot * multiple;

   for(int i = 1; i <= totalStops; i++)
   {
      // chuẩn hóa lot
      double finalLot = MathFloor(lot / stepLot) * stepLot;
      finalLot = NormalizeDouble(finalLot, 2);

      if(finalLot < minLot)
      {
         Print("Lot quá nhỏ, bỏ qua cấp ", i);
         return;
      }

      double price = ask + i * distancePoint * _Point;

      if(!trade.BuyStop(finalLot, price, _Symbol))
         Print("BuyStop cấp ", i, " lỗi: ", trade.ResultRetcodeDescription());

      lot *= multiple;
   }
}

void PlaceSellStopDCA(double baseLot, double multiple, int totalStops, int distancePoint)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // lot sell stop đầu tiên = lot gốc × multiple
   double lot = baseLot * multiple;

   for(int i = 1; i <= totalStops; i++)
   {
      // chuẩn hóa lot
      double finalLot = MathFloor(lot / stepLot) * stepLot;
      finalLot = NormalizeDouble(finalLot, 2);

      if(finalLot < minLot)
      {
         Print("Lot quá nhỏ, bỏ qua cấp ", i);
         return;
      }

      // SELL STOP đặt DƯỚI giá hiện tại
      double price = bid - i * distancePoint * _Point;

      if(!trade.SellStop(finalLot, price, _Symbol))
         Print("SellStop cấp ", i, " lỗi: ", trade.ResultRetcodeDescription());

      lot *= multiple;
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

bool IsTradingTimeVN()
{
   datetime serverTime = TimeCurrent();
   datetime vnTime     = serverTime + 7 * 3600; // GMT+7

   MqlDateTime t;
   TimeToStruct(vnTime, t);

   int hour = t.hour;

   // ❌ Cấm vào lệnh từ 01:00 → 06:59 giờ VN
   if(hour >= Timestart && hour < Timeend)
      return false;

   return true;
}

int CountBuyPositions()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            count++;
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
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            count++;
      }
   }
   return count;
}

bool GetLastSellPosition(double &lastPrice, double &lastLot)
{
   datetime newestTime = 0;
   bool found = false;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            datetime openTime =
               (datetime)PositionGetInteger(POSITION_TIME);

            if(openTime > newestTime)
            {
               newestTime = openTime;
               lastPrice  = PositionGetDouble(POSITION_PRICE_OPEN);
               lastLot    = PositionGetDouble(POSITION_VOLUME);
               found = true;
            }
         }
      }
   }

   return found;
}

void OpenSellStopBelowLastSell(double distance_points,
                               double lotMultiplier,
                               int numberOfOrders)
{
   double lastPrice, lastLot;

   if(!GetLastSellPosition(lastPrice, lastLot))
   {
      Print("Không có lệnh Sell nào đang mở");
      return;
   }

   string symbol = _Symbol;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   for(int n = 1; n <= numberOfOrders; n++)
   {
      double newLot = lastLot * MathPow(lotMultiplier, n);

      newLot = MathMax(newLot, minLot);
      newLot = NormalizeDouble(MathFloor(newLot/lotStep)*lotStep, 2);

      double price = NormalizeDouble(
                     lastPrice - n * distance_points * point,
                     _Digits);

      trade.SellStop(newLot, price, symbol, 0, 0);
   }

   Print("Đã mở ", numberOfOrders,
         " Sell Stop dưới Sell mở muộn nhất");
}

bool GetLastBuyPosition(double &lastPrice, double &lastLot)
{
   datetime newestTime = 0;
   bool found = false;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            datetime openTime =
               (datetime)PositionGetInteger(POSITION_TIME);

            if(openTime > newestTime)
            {
               newestTime = openTime;
               lastPrice  = PositionGetDouble(POSITION_PRICE_OPEN);
               lastLot    = PositionGetDouble(POSITION_VOLUME);
               found = true;
            }
         }
      }
   }

   return found;
}

void OpenBuyStopAboveLastBuy(double distance_points,
                             double lotMultiplier,
                             int numberOfOrders)
{
   double lastPrice, lastLot;

   if(!GetLastBuyPosition(lastPrice, lastLot))
   {
      Print("Không có lệnh Buy nào đang mở");
      return;
   }

   string symbol = _Symbol;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   for(int n = 1; n <= numberOfOrders; n++)
   {
      double newLot = lastLot * MathPow(lotMultiplier, n);

      newLot = MathMax(newLot, minLot);
      newLot = NormalizeDouble(MathFloor(newLot/lotStep)*lotStep, 2);

      double price = NormalizeDouble(
                     lastPrice + n * distance_points * point,
                     _Digits);

      trade.BuyStop(newLot, price, symbol, 0, 0);
   }

   Print("Đã mở ", numberOfOrders,
         " Buy Stop phía trên Buy mở muộn nhất");
}