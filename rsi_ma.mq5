//+------------------------------------------------------------------+
//|                                                       rsi_ma.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
input int chuki_rsi=10;// Chu kỳ RSI
input int chuki_ema=50;// Chu kỳ EMA
input int chuki_wma=200;// Chu kỳ WMA
ENUM_TIMEFRAMES khung_1=PERIOD_M15;
ENUM_TIMEFRAMES khung_2=PERIOD_H8;
ENUM_TIMEFRAMES khung_3=PERIOD_H4;
ENUM_TIMEFRAMES khung_4=PERIOD_H1;
input double lot=0.1;// Lot vào lệnh
input long sl=4;// SL
input long tp=8;// TP
int get_rsi_1;
double rsi_arr_1[];
int get_ema_1;
double ema_arr_1[];
int get_wma_1;
double wma_arr_1[];

int get_rsi_2;
double rsi_arr_2[];
int get_ema_2;
double ema_arr_2[];
int get_wma_2;
double wma_arr_2[];

int get_rsi_3;
double rsi_arr_3[];
int get_ema_3;
double ema_arr_3[];
int get_wma_3;
double wma_arr_3[];

int get_rsi_4;
double rsi_arr_4[];
int get_ema_4;
double ema_arr_4[];
int get_wma_4;
double wma_arr_4[];
int last=-1;
datetime last_bar_time=0;
double Ask,Bid;
int OnInit()
  {
//---
   ArraySetAsSeries(rsi_arr_1,true);
   ArraySetAsSeries(wma_arr_1,true);
   ArraySetAsSeries(ema_arr_1,true);
   ArraySetAsSeries(rsi_arr_2,true);
   ArraySetAsSeries(wma_arr_2,true);
   ArraySetAsSeries(ema_arr_2,true);
   ArraySetAsSeries(rsi_arr_3,true);
   ArraySetAsSeries(wma_arr_3,true);
   ArraySetAsSeries(ema_arr_3,true);
   ArraySetAsSeries(rsi_arr_4,true);
   ArraySetAsSeries(wma_arr_4,true);
   ArraySetAsSeries(ema_arr_4,true);
   get_rsi_1=iRSI(Symbol(),khung_1,chuki_rsi,PRICE_CLOSE);
   get_ema_1=iMA(Symbol(),khung_1,chuki_ema,0,MODE_EMA,get_rsi_1);
   get_wma_1=iMA(Symbol(),khung_1,chuki_wma,0,MODE_LWMA,get_rsi_1);
   
    get_rsi_2=iRSI(Symbol(),khung_2,chuki_rsi,PRICE_CLOSE);
   get_ema_2=iMA(Symbol(),khung_2,chuki_ema,0,MODE_EMA,get_rsi_2);
   get_wma_2=iMA(Symbol(),khung_2,chuki_wma,0,MODE_LWMA,get_rsi_2);
   
    get_rsi_3=iRSI(Symbol(),khung_3,chuki_rsi,PRICE_CLOSE);
   get_ema_3=iMA(Symbol(),khung_3,chuki_ema,0,MODE_EMA,get_rsi_3);
   get_wma_3=iMA(Symbol(),khung_3,chuki_wma,0,MODE_LWMA,get_rsi_3);
   
    get_rsi_4=iRSI(Symbol(),khung_4,chuki_rsi,PRICE_CLOSE);
   get_ema_4=iMA(Symbol(),khung_4,chuki_ema,0,MODE_EMA,get_rsi_4);
   get_wma_4=iMA(Symbol(),khung_4,chuki_wma,0,MODE_LWMA,get_rsi_4);
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   datetime current_bar = iTime(Symbol(),khung_1,0);

   if(current_bar == last_bar_time)
      return;
   
   last_bar_time = current_bar;
   Ask = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   Bid = SymbolInfoDouble(Symbol(),SYMBOL_BID);
   
   
   CopyBuffer(get_rsi_1,0,0,4,rsi_arr_1);
   CopyBuffer(get_ema_1,0,0,4,ema_arr_1);
   CopyBuffer(get_wma_1,0,0,4,wma_arr_1);

   double rsi1_1=NormalizeDouble(rsi_arr_1[1],2);
   double rsi0_1=NormalizeDouble(rsi_arr_1[0],2);

   double ema1_1=NormalizeDouble(ema_arr_1[1],2);
   double ema0_1=NormalizeDouble(ema_arr_1[0],2);

   double wma1_1=NormalizeDouble(wma_arr_1[1],2);
   double wma0_1=NormalizeDouble(wma_arr_1[0],2);
   
  
   CopyBuffer(get_rsi_2,0,0,4,rsi_arr_2);
   CopyBuffer(get_ema_2,0,0,4,ema_arr_2);
   CopyBuffer(get_wma_2,0,0,4,wma_arr_2);

   double rsi1_2=NormalizeDouble(rsi_arr_2[1],2);
   double rsi0_2=NormalizeDouble(rsi_arr_2[0],2);

   double ema1_2=NormalizeDouble(ema_arr_2[1],2);
   double ema0_2=NormalizeDouble(ema_arr_2[0],2);

   double wma1_2=NormalizeDouble(wma_arr_2[1],2);
   double wma0_2=NormalizeDouble(wma_arr_2[0],2);
   
  
   CopyBuffer(get_rsi_3,0,0,4,rsi_arr_3);
   CopyBuffer(get_ema_3,0,0,4,ema_arr_3);
   CopyBuffer(get_wma_3,0,0,4,wma_arr_3);

   double rsi1_3=NormalizeDouble(rsi_arr_3[1],2);
   double rsi0_3=NormalizeDouble(rsi_arr_3[0],2);

   double ema1_3=NormalizeDouble(ema_arr_3[1],2);
   double ema0_3=NormalizeDouble(ema_arr_3[0],2);

   double wma1_3=NormalizeDouble(wma_arr_3[1],2);
   double wma0_3=NormalizeDouble(wma_arr_3[0],2);
   
  
   CopyBuffer(get_rsi_4,0,0,4,rsi_arr_4);
   CopyBuffer(get_ema_4,0,0,4,ema_arr_4);
   CopyBuffer(get_wma_4,0,0,4,wma_arr_4);

   double rsi1_4=NormalizeDouble(rsi_arr_4[1],2);
   double rsi0_4=NormalizeDouble(rsi_arr_4[0],2);

   double ema1_4=NormalizeDouble(ema_arr_4[1],2);
   double ema0_4=NormalizeDouble(ema_arr_4[0],2);

   double wma1_4=NormalizeDouble(wma_arr_4[1],2);
   double wma0_4=NormalizeDouble(wma_arr_4[0],2);
   CopyBuffer(get_rsi_1,0,0,10,rsi_arr_1);
   CopyBuffer(get_ema_1,0,0,10,ema_arr_1);
   CopyBuffer(get_wma_1,0,0,10,wma_arr_1);
   //Comment(rsi1 +" " + ema1 +" "+wma1);
   bool cross_ema_up =
   (rsi_arr_1[2] < ema_arr_1[2] &&
    rsi_arr_1[1] > ema_arr_1[1]);
   
   bool cross_wma_up =
   (rsi_arr_1[2] < wma_arr_1[2] &&
    rsi_arr_1[1] > wma_arr_1[1]);
   
   bool valid_ema =
   !CheckPreviousBarsAbove(rsi_arr_1,ema_arr_1,7);
   
   bool valid_wma =
   !CheckPreviousBarsAbove(rsi_arr_1,wma_arr_1,7);
   
   bool buy_m15 =
   (
      (cross_ema_up && rsi0_1 > wma0_1 && valid_ema) ||
      (cross_wma_up && rsi0_1 > ema0_1 && valid_wma)
   );
   bool cross_ema_down =
   (rsi_arr_1[2] > ema_arr_1[2] &&
    rsi_arr_1[1] < ema_arr_1[1]);
   
   bool cross_wma_down =
   (rsi_arr_1[2] > wma_arr_1[2] &&
    rsi_arr_1[1] < wma_arr_1[1]);
   
   bool valid_ema_sell =
   !CheckPreviousBarsBelow(rsi_arr_1,ema_arr_1,7);
   
   bool valid_wma_sell =
   !CheckPreviousBarsBelow(rsi_arr_1,wma_arr_1,7);
   
   bool sell_m15 =
   (
      (cross_ema_down && rsi0_1 < wma0_1 && valid_ema_sell) ||
      (cross_wma_down && rsi0_1 < ema0_1 && valid_wma_sell)
   );
   // đóng BUY nếu có tín hiệu SELL
   if(sell_m15 && last == 0)
   {
      ClosePosition(POSITION_TYPE_BUY);
      last = -1;
   }
   
   // đóng SELL nếu có tín hiệu BUY
   if(buy_m15 && last == 1)
   {
      ClosePosition(POSITION_TYPE_SELL);
      last = -1;
   }
   if(buy_m15 && ema1_2 < rsi1_2 && wma1_2 < rsi1_2 &&  ema1_3 < rsi1_3 && wma1_3 < rsi1_3 &&  ema1_4 < rsi1_4 && wma1_4 < rsi1_4 && last!=0)
     {
      MqlTradeRequest request= {};
      MqlTradeResult result= {};
      request.action=TRADE_ACTION_DEAL;
      request.deviation=20;
      request.type=ORDER_TYPE_BUY;
      request.price=Ask;
      request.sl=Ask-sl;
      request.tp=Ask+tp;
      request.symbol=_Symbol;
      request.volume=lot;
      OrderSend(request,result);
      last=0;

     }

   if(sell_m15 && ema1_2 > rsi1_2 && wma1_2 > rsi1_2 && ema1_3 > rsi1_3 && wma1_3 > rsi1_3 && ema1_4 > rsi1_4 && wma1_4 > rsi1_4 && last!=1)
     {

      MqlTradeRequest request= {};
      MqlTradeResult result= {};
      request.action=TRADE_ACTION_DEAL;
      request.deviation=20;
      request.type=ORDER_TYPE_SELL;
      request.price=Bid;
      request.sl=Bid+sl;
      request.tp=Bid-tp;
      request.symbol=_Symbol;
      request.volume=lot;
      OrderSend(request,result);
      last=1;
     }
     
     //if(last==0 && (ema1_1 > rsi1_1 || wma1_1 > rsi1_1 || ema1_2 > rsi1_2 || wma1_2 > rsi1_2 || ema1_3 > rsi1_3 || wma1_3 > rsi1_3 || ema1_4 > rsi1_4 || wma1_4 > rsi1_4 )) last=-1;
     //if(last==1 && (ema1_1 < rsi1_1 || wma1_1 < rsi1_1 || ema1_2 < rsi1_2 || wma1_2 < rsi1_2 || ema1_3 < rsi1_3 || wma1_3 < rsi1_3 || ema1_4 < rsi1_4 || wma1_4 < rsi1_4 )) last=-1;

  }
//+------------------------------------------------------------------+
void ClosePosition(int type)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
            PositionGetInteger(POSITION_TYPE)==type)
         {
            MqlTradeRequest request={};
            MqlTradeResult result={};

            request.action=TRADE_ACTION_DEAL;
            request.position=ticket;
            request.symbol=_Symbol;
            request.volume=PositionGetDouble(POSITION_VOLUME);
            request.deviation=20;

            if(type==POSITION_TYPE_BUY)
            {
               request.type=ORDER_TYPE_SELL;
               request.price=Bid;
            }
            else
            {
               request.type=ORDER_TYPE_BUY;
               request.price=Ask;
            }

            OrderSend(request,result);
         }
      }
   }
}
bool CheckPreviousBarsAbove(double &rsi[], double &ma[], int bars)
{
   for(int i=2;i<=bars+1;i++)
   {
      if(rsi[i] > ma[i])
         return true;
   }
   return false;
}

bool CheckPreviousBarsBelow(double &rsi[], double &ma[], int bars)
{
   for(int i=2;i<=bars+1;i++)
   {
      if(rsi[i] < ma[i])
         return true;
   }
   return false;
}