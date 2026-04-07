//+------------------------------------------------------------------+
//| Auto Set SL TP if Missing                                        |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

CTrade trade;

// ==== INPUT ====
input double StopLoss_Points  = 3;   // SL 
input double TakeProfit_Points = 6;  // TP
//+------------------------------------------------------------------+
//| Hàm kiểm tra và cài SL TP                                       |
//+------------------------------------------------------------------+
void CheckPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol != _Symbol)
         continue;

      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double price_open = PositionGetDouble(POSITION_PRICE_OPEN);
      int type = (int)PositionGetInteger(POSITION_TYPE);

      // Nếu đã có SL và TP thì bỏ qua
      if(sl > 0 && tp > 0)
         continue;

      double newSL = sl;
      double newTP = tp;

      // BUY
      if(type == POSITION_TYPE_BUY)
      {
         if(sl == 0)
            newSL = price_open - StopLoss_Points;

         if(tp == 0)
            newTP = price_open + TakeProfit_Points;
      }

      // SELL
      if(type == POSITION_TYPE_SELL)
      {
         if(sl == 0)
            newSL = price_open + StopLoss_Points;

         if(tp == 0)
            newTP = price_open - TakeProfit_Points;
      }

      trade.PositionModify(ticket,newSL,newTP);
   }
}

//+------------------------------------------------------------------+
//| Tick                                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   CheckPositions();
}