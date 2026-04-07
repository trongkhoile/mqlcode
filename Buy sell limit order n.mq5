#property strict
#include <Trade/Trade.mqh>

CTrade trade;

// INPUT
input int GridOrders=5;// Số lệnh buy sell limit stop trên dưới
input double GridStep=1; // Khoảng cách
input double LotSize=0.01;// Lot
input double TakeProfit=1; // TP
double startBuyPrice;
double startSellPrice;
double mid;

//--------------------------------

void PlaceOrder(ENUM_ORDER_TYPE type,double price,string comment)
{
   double tp=0;
   CTrade trade;
   trade.SetAsyncMode(true);
   if(type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY_STOP)
      tp=price+TakeProfit;

   if(type==ORDER_TYPE_SELL_LIMIT || type==ORDER_TYPE_SELL_STOP)
      tp=price-TakeProfit;

   bool result=false;

   // thử đặt lệnh ban đầu
   if(type==ORDER_TYPE_BUY_LIMIT)
      result=trade.BuyLimit(LotSize,price,_Symbol,0,tp,ORDER_TIME_GTC,0,comment);

   if(type==ORDER_TYPE_BUY_STOP)
      result=trade.BuyStop(LotSize,price,_Symbol,0,tp,ORDER_TIME_GTC,0,comment);

   if(type==ORDER_TYPE_SELL_LIMIT)
      result=trade.SellLimit(LotSize,price,_Symbol,0,tp,ORDER_TIME_GTC,0,comment);

   if(type==ORDER_TYPE_SELL_STOP)
      result=trade.SellStop(LotSize,price,_Symbol,0,tp,ORDER_TIME_GTC,0,comment);

   // nếu lỗi → đảo loại lệnh
   if(!result)
   {
      Print("Order failed ",comment," trying reverse type");

      if(type==ORDER_TYPE_BUY_LIMIT)
         trade.BuyStop(LotSize,price,_Symbol,0,tp,ORDER_TIME_GTC,0,comment);

      else if(type==ORDER_TYPE_BUY_STOP)
         trade.BuyLimit(LotSize,price,_Symbol,0,tp,ORDER_TIME_GTC,0,comment);

      else if(type==ORDER_TYPE_SELL_LIMIT)
         trade.SellStop(LotSize,price,_Symbol,0,tp,ORDER_TIME_GTC,0,comment);

      else if(type==ORDER_TYPE_SELL_STOP)
         trade.SellLimit(LotSize,price,_Symbol,0,tp,ORDER_TIME_GTC,0,comment);
   }
}
//--------------------------------

bool OrderExists(string comment)
{
   for(int i=0;i<OrdersTotal();i++)
   {
      ulong ticket=OrderGetTicket(i);
      if(OrderSelect(ticket))
         if(OrderGetString(ORDER_COMMENT)==comment)
            return true;
   }

   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
         if(PositionGetString(POSITION_COMMENT)==comment)
            return true;
   }

   return false;
}

//--------------------------------

void CheckGrid()
{
   for(int i=1;i<=GridOrders;i++)
   {
      double distance=GridStep*i;

      double below=mid-distance;
      double above=mid+distance;
      string buyLimit="buy_"+IntegerToString(i);
      string buyStop="buy_"+IntegerToString(GridOrders+i);

      string sellLimit="sell_"+IntegerToString(i);
      string sellStop="sell_"+IntegerToString(GridOrders+i);

      if(!OrderExists(buyLimit))
         PlaceOrder(ORDER_TYPE_BUY_STOP,below,buyLimit);

      if(!OrderExists(buyStop))
         PlaceOrder(ORDER_TYPE_BUY_LIMIT,above,buyStop);

      if(!OrderExists(sellLimit))
         PlaceOrder(ORDER_TYPE_SELL_STOP,above,sellLimit);

      if(!OrderExists(sellStop))
         PlaceOrder(ORDER_TYPE_SELL_LIMIT,below,sellStop);
   }
}

void CheckGrid1()
{
   for(int i=1;i<=GridOrders;i++)
   {
      double distance=GridStep*i;

      double below=mid-distance;
      double above=mid+distance;
      
      string buyLimit="buy_"+IntegerToString(i);
      string buyStop="buy_"+IntegerToString(GridOrders+i);

      string sellLimit="sell_"+IntegerToString(i);
      string sellStop="sell_"+IntegerToString(GridOrders+i);

      if(!OrderExists(buyLimit))
         PlaceOrder(ORDER_TYPE_BUY_LIMIT,below,buyLimit);

      if(!OrderExists(buyStop))
         PlaceOrder(ORDER_TYPE_BUY_LIMIT,above,buyStop);

      if(!OrderExists(sellLimit))
         PlaceOrder(ORDER_TYPE_SELL_LIMIT,above,sellLimit);

      if(!OrderExists(sellStop))
         PlaceOrder(ORDER_TYPE_SELL_LIMIT,below,sellStop);
   }
}

void OpenFirstPair()
{
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);

   if(!OrderExists("buy_0"))
      trade.Buy(LotSize,_Symbol,ask,0,ask+TakeProfit,"buy_0");

   if(!OrderExists("sell_0"))
      trade.Sell(LotSize,_Symbol,bid,0,bid-TakeProfit,"sell_0");
}

bool PositionExists(string comment)
{
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);

      if(PositionSelectByTicket(ticket))
         if(PositionGetString(POSITION_COMMENT)==comment)
            return true;
   }

   return false;
}
//--------------------------------
void CheckCenterOrders()
{
   if(!OrderExists("buy_0"))
      PlaceOrder(ORDER_TYPE_BUY_LIMIT,startBuyPrice,"buy_0");

   if(!OrderExists("sell_0"))
      PlaceOrder(ORDER_TYPE_SELL_LIMIT,startSellPrice,"sell_0");
}

int OnInit()
{
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);

   mid=(ask+bid)/2;
   startBuyPrice=ask;
   startSellPrice=bid;
   // mở cặp lệnh đầu tiên
   OpenFirstPair();
   CheckGrid();

   return(INIT_SUCCEEDED);
}

//--------------------------------

void OnTick()
{
   CheckCenterOrders();
   CheckGrid1();
}