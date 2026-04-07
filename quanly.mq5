
#property copyright "RiskManager EA"
#property version   "2.02"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//========== INPUTS ==========
input group "=== 1. cai dat SL ==="
input double  InpMaxSLAmount   = 100.0;  // MaxSL per lenh (USD)
input double  InpSLPercent     = 0.8;    // % MaxSL = 1 lenh SL 

input group "=== 2. cai dat SL lien tuc ==="
input int     InpMaxConsecSL   = 3;      // so lenh lien tiep
input int     InpBlockSeconds  = 300;    // (X) giay chan

input group "=== 3. Thoi gian giua cac lenh ==="
input int     InpMinSeconds    = 60;     // (Y) giay toi thieu giua 2 lenh 

input group "=== 4. Khoang cach cac lenh ==="
input int     InpMinPips       = 30;     // (Z) pip toi thieu cung chieu 
 double  InpPipSize       = 0.1;    // Pip size 

input group "=== 5. Daily Profit Lock ==="
input double  InpDailyMulti    = 3.0;   // Ti so profit trong ngay
input int     InpDailyLockSec  = 3600;  // Khoa khong cho vao lenh bn giay

//========== GLOBALS ==========
double    g_slThresh;        
double    g_winThresh;       

datetime  g_lastOpenTime   = 0;
double    g_lastPrice      = 0.0;
int       g_lastType       = -1;      // 0=BUY 1=SELL
bool      g_instantClose   = false;

int       g_consecSL       = 0;
datetime  g_blockUntil     = 0;
datetime  g_dailyLockUntil = 0;
double    g_dailyProfit    = 0.0;
datetime  g_dailyReset     = 0;
datetime  g_lastDeal       = 0;

double Ask, Bid;

// Struct de luu tru thong tin lenh dang mo (Cho viec chan lenh vao tay)
struct OpenPos {
   ulong ticket;
   datetime time;
   double price;
   int type;
};


datetime Get0650Server(int daysOffset = 0)
{
   int vnOff = 7 * 3600; // UTC+7
   datetime nowVN = TimeCurrent() + vnOff;
   MqlDateTime dt; TimeToStruct(nowVN, dt);
   dt.hour = 6; dt.min = 50; dt.sec = 0;
   return StructToTime(dt) - vnOff + daysOffset * 86400;
}

datetime GetTodayStart()
{
   datetime t = Get0650Server(0);
   if(TimeCurrent() < t) t -= 86400;
   return t;
}


void LoadDailyProfit()
{
   g_dailyProfit = 0;
   if(!HistorySelect(GetTodayStart(), TimeCurrent()+1)) return;
   int n = HistoryDealsTotal();
   for(int i=0;i<n;i++)
   {
      ulong t = HistoryDealGetTicket(i);
      if(!t) continue;
      long en = HistoryDealGetInteger(t,DEAL_ENTRY);
      if(en!=DEAL_ENTRY_OUT && en!=DEAL_ENTRY_INOUT) continue;
      double pnl = HistoryDealGetDouble(t,DEAL_PROFIT)
                 + HistoryDealGetDouble(t,DEAL_COMMISSION)
                 + HistoryDealGetDouble(t,DEAL_SWAP);
      g_dailyProfit += pnl;
      datetime dt2=(datetime)HistoryDealGetInteger(t,DEAL_TIME);
      if(dt2>g_lastDeal) g_lastDeal=dt2;
   }
}


string Classify(double pnl)
{
   if(pnl >= g_winThresh)  return "WIN";
   if(pnl <= -g_slThresh)  return "SL";
   return "BE";
}


void CheckDailyReset()
{
   if(TimeCurrent() >= g_dailyReset)
   {
      Print("[DAILY RESET] ", TimeToString(TimeCurrent()));
      g_dailyProfit    = 0;
      g_dailyLockUntil = 0;
      g_consecSL       = 0;
      g_blockUntil     = 0;
      g_dailyReset     = Get0650Server(1);
      if(TimeCurrent() < Get0650Server(0)) g_dailyReset = Get0650Server(0);
   }
}


void CheckClosedDeals()
{
   datetime from = (g_lastDeal>0) ? g_lastDeal : GetTodayStart();
   if(!HistorySelect(from, TimeCurrent()+1)) return;
   int n = HistoryDealsTotal();
   for(int i=0;i<n;i++)
   {
      ulong tk = HistoryDealGetTicket(i);
      if(!tk) continue;
      long en = HistoryDealGetInteger(tk,DEAL_ENTRY);
      if(en!=DEAL_ENTRY_OUT && en!=DEAL_ENTRY_INOUT) continue;
      datetime dt=(datetime)HistoryDealGetInteger(tk,DEAL_TIME);
      if(dt <= g_lastDeal) continue;
      if(dt < GetTodayStart()) { g_lastDeal=dt; continue; }

      double pnl = HistoryDealGetDouble(tk,DEAL_PROFIT)
                 + HistoryDealGetDouble(tk,DEAL_COMMISSION)
                 + HistoryDealGetDouble(tk,DEAL_SWAP);
      g_dailyProfit += pnl;
      
      // Instant close?
      g_instantClose = (dt - g_lastOpenTime <= 1 && g_lastOpenTime > 0);

      string res = Classify(pnl);
      Print(StringFormat("[CLOSED] pnl=%.2f res=%s consecSL=%d daily=%.2f",
            pnl, res, g_consecSL, g_dailyProfit));

      if(res == "WIN")
      {
         g_consecSL   = 0;
         g_blockUntil = 0;
         Print("[WIN] Reset consec SL, unblock");
      }
      else if(res == "SL") // BE bo qua, khong cong don
      {
         g_consecSL++;
         if(g_consecSL >= InpMaxConsecSL)
         {
            g_blockUntil = TimeCurrent() + InpBlockSeconds;
            Print(StringFormat("[BLOCK] %d consec => block %ds until %s",
                  g_consecSL, InpBlockSeconds, TimeToString(g_blockUntil)));
         }
      }

      // Daily profit lock
      double lockTh = InpMaxSLAmount * InpDailyMulti;
      if(g_dailyProfit <= -lockTh && g_dailyLockUntil <= TimeCurrent())
      {
         g_dailyLockUntil = TimeCurrent() + InpDailyLockSec;
         Print(StringFormat("[DAILY LOCK] profit %.2f >= %.2f => lock %ds until %s",
               g_dailyProfit, lockTh, InpDailyLockSec, TimeToString(g_dailyLockUntil)));
      }

      g_lastDeal = dt;
   }
}


void EnforceManualEntryRules()
{
   int total = PositionsTotal();
   if(total == 0) return;
   
   OpenPos arr[];
   int count = 0;
   
   for(int i = total - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         ulong tk = PositionGetInteger(POSITION_TICKET);
         datetime opTime = (datetime)PositionGetInteger(POSITION_TIME);
         
         // 1. Phai vao lenh luc dang bi Block / Daily Lock khong? -> Cat ngay
         if(opTime < g_blockUntil)
         {
            Print("[INTERCEPT] Vao lenh luc dang bi BLOCK. Dong ngay: #", tk);
            trade.PositionClose(tk);
            continue; 
         }
         if(opTime < g_dailyLockUntil)
         {
            Print("[INTERCEPT] Vao lenh luc dang bi DAILY LOCK. Dong ngay: #", tk);
            trade.PositionClose(tk);
            continue;
         }
         
         ArrayResize(arr, count + 1);
         arr[count].ticket = tk;
         arr[count].time   = opTime;
         arr[count].price  = PositionGetDouble(POSITION_PRICE_OPEN);
         arr[count].type   = (int)PositionGetInteger(POSITION_TYPE);
         count++;
      }
   }
   
   if(count < 2) return; 
   
   // Sap xep mang tu lenh vao cu nhat -> lenh moi nhat
   for(int i = 0; i < count - 1; i++)
   {
      for(int j = i + 1; j < count; j++)
      {
         if(arr[i].time > arr[j].time)
         {
            OpenPos tmp = arr[i];
            arr[i] = arr[j];
            arr[j] = tmp;
         }
      }
   }
   
   // 2. Kiem tra rule Y giay (Chung) va Z pips (Rieng tung chieu Buy/Sell)
   datetime lastValidTime = arr[0].time;
   double lastValidBuyPrice = (arr[0].type == ORDER_TYPE_BUY) ? arr[0].price : 0;
   double lastValidSellPrice = (arr[0].type == ORDER_TYPE_SELL) ? arr[0].price : 0;
   
   for(int i = 1; i < count; i++)
   {
      OpenPos curr = arr[i];
      bool violation = false;
      string reason = "";
      
      // Kiem tra du Y giay chua (Ap dung cho MOI lenh truoc do)
      if(curr.time - lastValidTime <= InpMinSeconds)
      {
         violation = true;
         reason = StringFormat("Chua du %d giay giua 2 lenh", InpMinSeconds);
      }
      else
      {
         // Kiem tra Z pips so voi lenh CUNG LOAI gan nhat
         double dist = InpMinPips * InpPipSize;
         if(curr.type == ORDER_TYPE_BUY && lastValidBuyPrice > 0 && curr.price <= lastValidBuyPrice + dist)
         {
            violation = true;
            reason = StringFormat("Gia BUY %.5f chua du Z pips so voi BUY cu %.5f", curr.price, lastValidBuyPrice);
         }
         else if(curr.type == ORDER_TYPE_SELL && lastValidSellPrice > 0 && curr.price > lastValidSellPrice - dist)
         {
            violation = true;
            reason = StringFormat("Gia SELL %.5f chua du Z pips so voi SELL cu %.5f", curr.price, lastValidSellPrice);
         }
      }
      
      // Xu ly ket qua
      if(violation)
      {
         Print("[INTERCEPT] Dong lenh #", curr.ticket, " do vi pham: ", reason);
         trade.PositionClose(curr.ticket);
      }
      else
      {
         // Neu lenh hop le -> Luu lai lam moc cho lenh tiep theo
         lastValidTime = curr.time;
         if(curr.type == ORDER_TYPE_BUY) lastValidBuyPrice = curr.price;
         if(curr.type == ORDER_TYPE_SELL) lastValidSellPrice = curr.price;
      }
   }
}


void MonitorOpenPos()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         double pnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
         ulong tk = PositionGetInteger(POSITION_TICKET);
         
         if(pnl <= -InpMaxSLAmount)
         {
            Print(StringFormat("[FORCE CLOSE SL] Ticket #%llu | loss %.2f <= -MaxSL %.2f", tk, pnl, InpMaxSLAmount));
            trade.PositionClose(tk);
         }
         else if(pnl >= InpMaxSLAmount)
         {
            Print(StringFormat("[FORCE CLOSE TP] Ticket #%llu | profit %.2f >= WIN Thresh %.2f", tk, pnl, InpMaxSLAmount));
            trade.PositionClose(tk);
         }
      }
   }
}


void CheckExpiry()
{
   if(g_blockUntil>0 && TimeCurrent()>=g_blockUntil)
   {
      Print("[BLOCK EXPIRED] Reset consecSL");
      g_blockUntil=0; g_consecSL=0;
   }
   if(g_dailyLockUntil>0 && TimeCurrent()>=g_dailyLockUntil)
   {
      Print("[DAILY LOCK EXPIRED] Reset daily profit");
      g_dailyLockUntil=0; g_dailyProfit=0;
   }
}


bool CanOpenTrade(int orderType, double price, string &reason)
{
   CheckExpiry();

   if(TimeCurrent() < g_blockUntil)
   {
      reason = StringFormat("CONSEC_BLOCK: con %ds", (int)(g_blockUntil-TimeCurrent()));
      return false;
   }
   if(TimeCurrent() < g_dailyLockUntil)
   {
      reason = StringFormat("DAILY_LOCK: con %ds", (int)(g_dailyLockUntil-TimeCurrent()));
      return false;
   }
   
   // Tim lenh mo gan nhat bat ky (de check thoi gian Y giay) 
   // Va tim lenh CUNG CHIEU gan nhat (de check khoang cach Z pip)
   datetime lastGlobalTime = 0;
   datetime lastSameTypeTime = 0;
   double lastSameTypePrice = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         datetime t = (datetime)PositionGetInteger(POSITION_TIME);
         if(t > lastGlobalTime) lastGlobalTime = t;
         
         if(PositionGetInteger(POSITION_TYPE) == orderType)
         {
            if(t > lastSameTypeTime)
            {
               lastSameTypeTime = t;
               lastSameTypePrice = PositionGetDouble(POSITION_PRICE_OPEN); 
            }
         }
      }
   }

   // 1. Check thoi gian (so voi bat ky lenh nao gan nhat)
   if(lastGlobalTime > 0)
   {
      int el = (int)(TimeCurrent() - lastGlobalTime);
      if(el < InpMinSeconds)
      {
         reason = StringFormat("TIME_RULE: can them %ds", InpMinSeconds-el);
         return false;
      }
   }
   
   // 2. Check Z pip (chi so voi lenh cung chieu)
   if(lastSameTypePrice > 0)
   {
      double dist = InpMinPips * InpPipSize;
      if(orderType == ORDER_TYPE_BUY && price < lastSameTypePrice + dist)
      {
         reason = StringFormat("PIP_BUY: can >= %.5f (hien %.5f)", lastSameTypePrice+dist, price);
         return false;
      }
      if(orderType == ORDER_TYPE_SELL && price > lastSameTypePrice - dist)
      {
         reason = StringFormat("PIP_SELL: can <= %.5f (hien %.5f)", lastSameTypePrice-dist, price);
         return false;
      }
   }

   reason = "OK";
   return true;
}

//+------------------------------------------------------------------+
//| Dem so luong lenh theo loai (Phuc vu khoi test)                  |
//+------------------------------------------------------------------+
int CountOrders(string type, int magicc)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      string position_symbol=PositionGetSymbol(i);
      if(position_symbol == _Symbol)
      {
         if(type=="All") count ++;
         if(type=="AllLimitStop" && PositionGetInteger(POSITION_TYPE)>1) count ++;
         if(type=="OP_BUY" && PositionGetInteger(POSITION_TYPE)==0) count ++;
         if(type=="OP_SELL" && PositionGetInteger(POSITION_TYPE)==1) count ++;
      }
   }
   return count;
}


//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   g_slThresh  = InpMaxSLAmount * InpSLPercent;
   g_winThresh = InpMaxSLAmount;

   g_dailyReset = Get0650Server(0);
   if(TimeCurrent() >= g_dailyReset) g_dailyReset = Get0650Server(1);

   LoadDailyProfit();
   EventSetTimer(1);

   Print("=== RiskManager EA (Hybrid Test & Manual Mode) ===");
   Print("SL thresh=",g_slThresh," | WIN thresh=",g_winThresh);
   Print("Consec block: ",InpMaxConsecSL," SL (BE bo qua) => ",InpBlockSeconds,"s");
   Print("Time rule: ",InpMinSeconds,"s | Pip rule: ",InpMinPips," pips");
   Print("Daily lock: profit>=",InpMaxSLAmount*InpDailyMulti," => ",InpDailyLockSec,"s");
   Print("Daily profit nap lai: ",g_dailyProfit," USD");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int r) { EventKillTimer(); Comment(""); }


datetime tmp=TimeCurrent();
void OnTick()
{
   CheckDailyReset();
   CheckClosedDeals();          
   EnforceManualEntryRules();   
   MonitorOpenPos();            
   
   
   Ask = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   Bid = SymbolInfoDouble(Symbol(),SYMBOL_BID);
   string reason = "";
  /*
   if(CountOrders("OP_BUY",0)==0 && TimeCurrent()>tmp+50)
   {
      MqlTradeRequest request= {};
      MqlTradeResult result= {};
      request.action=TRADE_ACTION_DEAL;
      request.deviation=20;
      request.magic=0;
      request.type=ORDER_TYPE_BUY;
      request.price=Ask;
      request.symbol=_Symbol;
      request.volume=0.1;
      OrderSend(request,result);
      tmp=TimeCurrent();
   }
      /*
   if(CountOrders("OP_SELL",0)==0 && TimeCurrent()>tmp+50)
   {
      MqlTradeRequest request= {};
      MqlTradeResult result= {};
      request.action=TRADE_ACTION_DEAL;
      request.deviation=20;
      request.magic=0;
      request.type=ORDER_TYPE_SELL;
      request.price=Bid;
      request.symbol=_Symbol;
      request.volume=0.1;
      OrderSend(request,result);
      tmp=TimeCurrent();
   }
   */
   
   
}

void OnTimer()
{
   CheckExpiry();
   
   bool bl = (TimeCurrent() < g_blockUntil || TimeCurrent() < g_dailyLockUntil);
   string r = "";
   if(TimeCurrent() < g_blockUntil) r = StringFormat("CONSEC BLOCK: %ds", (int)(g_blockUntil - TimeCurrent()));
   else if(TimeCurrent() < g_dailyLockUntil) r = StringFormat("DAILY LOCK: %ds", (int)(g_dailyLockUntil - TimeCurrent()));
   
   string d = StringFormat(
      "\n"
      "Trang thai : %s\n"
      "%s"
      "so lenh lo lien tiep: %d/%d\n"
      "Daily   : %.2f / %.2f USD\n"
      "SL>=    : %.2f | TP>= : %.2f\n"
      "Nxt Reset: %s",
      bl?"BLOCKED":" READY",
      bl?(r+"\n"):"",
      g_consecSL, InpMaxConsecSL,
      g_dailyProfit, InpMaxSLAmount*InpDailyMulti,
      g_slThresh, g_winThresh,
      TimeToString(g_dailyReset)
   );
   Comment(d);
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &req,
                        const MqlTradeResult  &res)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetInteger(trans.deal,DEAL_ENTRY)!=DEAL_ENTRY_IN) return;

   g_lastOpenTime = (datetime)HistoryDealGetInteger(trans.deal,DEAL_TIME);
   g_lastPrice    = HistoryDealGetDouble(trans.deal,DEAL_PRICE);
   g_lastType     = (int)HistoryDealGetInteger(trans.deal,DEAL_TYPE);
   g_instantClose = false;
   Print(StringFormat("[OPEN] %.5f %s @ %s",
         g_lastPrice, g_lastType==0?"BUY":"SELL", TimeToString(g_lastOpenTime)));
}