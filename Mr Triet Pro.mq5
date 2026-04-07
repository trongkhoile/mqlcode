#property strict
#include <Trade/Trade.mqh>

CTrade trade;

input double BaseLot    = 0.01; //Lot lệnh gốc đã có
input double Multiple   = 2.0;// Hệ số nhân
input int    Distance   = 300;  //Khoảng cách theo giá
input int    TotalStopsBuy = 4; // Số lệnh Buy Stop tối đa
input int    TotalStopsSell = 4;// Số lệnh Sell Stop tối đa
input int    TotalProfitTarget = 4;// Lợi nhuận thì đóng hết lệnh
input int   DistanceP2New = 10000;// Khoảng cách từ lệnh cuối đến lệnh đầu phần 2
input double BaseLotP2 = 0.05;// Lot gốc phần 2
input double DistanceP2 = 300;//Khoảng cách giữa các lệnh phần 2
input double MultipleP2 = 2;//Hệ số nhân phần 2
input int    BuyStopP2 = 2;//Số lệnh Buy Limit mở thêm phần 2
input int    SellStopP2 = 2;//Số lệnh Sell Limit mở thêm phần 2
input bool OnOffP2 = true;//Bật tắt phần 2
input bool OnOff = true; //Bật/tắt đóng lệnh khi đi hết lệnh
input int    Timestart = 23;// Giờ bắt đầu chạy Bot
input int    Timeend = 4;// Giờ bắt đầu tắt Bot
bool placed = false;
int checkbuy = 0;
int checksell = 0;
int checkall = 0;
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
      checkbuy = 0;
      checksell = 0;
   }
   if(CountBuyPositions() == TotalStopsBuy+1 && CountSellPositions() == TotalStopsSell+1 && OnOffP2 == false && OnOff == true){
      Close();
      checkbuy = 0;
      checksell = 0;
      checkall = 1;
   }
   if(checkall == 1){
      Close();
   }
   if(CountBuyPositions() == TotalStopsBuy+BuyStopP2+1 && CountSellPositions() == TotalStopsSell+SellStopP2+1 && OnOff == true)
   {
      Print("Max BUY & SELL reached → Close all");
      Close();
      checkbuy = 0;
      checksell =0;
      checkall =1;
   }
   if(OnOffP2 == true){
      if(checksell == 0 && !IsBuyStopExist()){
         OpenBuyStopAboveLastBuy(DistanceP2,MultipleP2,SellStopP2);
         
      }
      if(checkbuy == 0 && !IsSellStopExist()){
         OpenSellStopBelowLastSell(DistanceP2,MultipleP2,BuyStopP2);
      }
   }
   if(TotalFloatingProfit() >= TotalProfitTarget){
      Close();
      checkall = 1;
      checkbuy = 0;
      checksell =0;
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
   checkall =  0;
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

      if(!trade.BuyStop(finalLot, price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "BuyStop_DCA"))
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

      if(!trade.SellStop(finalLot, price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "SellStop_DCA"))
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
   datetime vnTime     = serverTime; // GMT+7

   MqlDateTime t;
   TimeToStruct(vnTime, t);

   int hour = t.hour;

   // ===== Trường hợp không qua ngày =====
   if(Timestart < Timeend)
   {
      if(hour >= Timestart && hour < Timeend)
         return true;
      else
         return false;
   }
   // ===== Trường hợp qua ngày (VD: 7h → 3h) =====
   else
   {
      if(hour >= Timestart || hour < Timeend)
         return true;
      else
         return false;
   }
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
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && PositionGetString(POSITION_COMMENT) == "SellStop_DCA")
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
      Print("Không có Sell Stop nào");
      return;
   }

   string symbol = _Symbol;
   double point   = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   // 👉 Giá lệnh đầu tiên cách Sell Stop 500 pip
   double firstPrice = lastPrice - DistanceP2New * _Point;

   for(int n = 0; n < numberOfOrders; n++)
   {
      double newLot = BaseLotP2 * MathPow(lotMultiplier, n);
      newLot = MathMax(newLot, minLot);
      newLot = NormalizeDouble(MathFloor(newLot/lotStep)*lotStep, 2);

      double price;

      if(n == 0)
      {
         price = firstPrice;
      }
      else
      {
         price = firstPrice - n * distance_points * point;
      }

      price = NormalizeDouble(price, _Digits);

      trade.BuyLimit(newLot, price, symbol, 0, 0);
   }

   checkbuy = 1;

   Print("Đã mở ", numberOfOrders,
         " Buy Limit dưới Sell Stop gần nhất");
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
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && PositionGetString(POSITION_COMMENT) == "BuyStop_DCA")
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
      Print("Không có Buy Stop nào");
      return;
   }

   string symbol = _Symbol;
   double point   = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   // 👉 Giá lệnh đầu tiên cách Buy Stop 1 khoảng cố định
   double firstPrice = lastPrice + DistanceP2New * _Point;

   for(int n = 0; n < numberOfOrders; n++)
   {
      double newLot = BaseLotP2 * MathPow(lotMultiplier, n);
      newLot = MathMax(newLot, minLot);
      newLot = NormalizeDouble(MathFloor(newLot/lotStep)*lotStep, 2);

      double price;

      if(n == 0)
      {
         price = firstPrice;
      }
      else
      {
         price = firstPrice + n * distance_points * point;
      }

      price = NormalizeDouble(price, _Digits);

      trade.SellLimit(newLot, price, symbol, 0, 0);
   }
   checksell = 1;
   Print("Đã mở ", numberOfOrders, " Sell Limit phía trên Buy Stop");
}

//--- Hàm tìm giá mở của lệnh BUY mở muộn nhất
double GetLastBuyPrice()
{
   double lastPrice = 0;
   datetime lastTime = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetTicket(i))
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

            if(openTime > lastTime)
            {
               lastTime  = openTime;
               lastPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            }
         }
      }
   }

   return lastPrice; // nếu không có BUY sẽ trả về 0
}

double GetLastSellPrice()
{
   double lastPrice = 0;
   datetime lastTime = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL &&
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

            if(openTime > lastTime)
            {
               lastTime = openTime;
               lastPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            }
         }
      }
   }

   return lastPrice;
}

bool IsPriceDown300Points()
{
   double lastSellPrice = GetLastSellPrice();

   if(lastSellPrice == 0)
      return false;

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(lastSellPrice - currentPrice >= DistanceP2New * _Point)
      return true;

   return false;
}

bool IsPriceUp300Points()
{
   double lastBuyPrice = GetLastBuyPrice();
   if(lastBuyPrice == 0)
      return false;

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(currentPrice - lastBuyPrice >= DistanceP2New * _Point)
      return true;

   return false;
}

bool IsSellStopExist()
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);

      if(OrderSelect(ticket))
      {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
            OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP)
         {
            return true; // Có Sell Stop
         }
      }
   }
   return false; // Không có Sell Stop
}
bool IsBuyStopExist()
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);

      if(OrderSelect(ticket))
      {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
            OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP)
         {
            return true; // Có Buy Stop
         }
      }
   }
   return false; // Không có Buy Stop
}