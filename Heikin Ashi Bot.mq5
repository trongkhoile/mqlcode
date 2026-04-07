#property strict
#include <Trade/Trade.mqh>
CTrade trade;

input string FileName = "signals.txt";   // File chứa tín hiệu từ TradingView
input double DefaultLot = 0.01;          // Lot mặc định
double Multiplier = 1.0;   // Hệ số nhân
input double StepPrice = 5.0; // khoảng cách cài stop theo giá
input double MultiplierLot = 2.0; // hệ số nhân lot
input double BE_Price = 1.0;      // giá chạy được để dời BE
input double TrailStep = 1.0;     // bước trailing theo GIÁ
double lot;
//=== Hàm trim khoảng trắng
string Trim(string s)
{
    StringTrimLeft(s);
    StringTrimRight(s);
    return s;
}
//=== Đọc toàn bộ file và loại bỏ xuống dòng
string ReadFileContent(string filename)
{
    int handle = FileOpen(filename, FILE_READ|FILE_TXT|FILE_SHARE_READ|FILE_ANSI);
    if(handle == INVALID_HANDLE)
    {
        Print("❌ Không mở được file: ", filename);
        return "";
    }

    string content = "";
    while(!FileIsEnding(handle))
    {
        content += FileReadString(handle);
    }
    FileClose(handle);

    // Loại bỏ ký tự xuống dòng và khoảng trắng thừa
    StringReplace(content, "\r\n", "");
    StringReplace(content, "\n", "");
    StringReplace(content, "\r", "");
    content = Trim(content);

    return content;
}

//=== Lấy giá trị từ JSON theo key
string GetJsonValue(string json, string key)
{
    int p = StringFind(json, "\"" + key + "\"");
    if(p == -1) return "";
    int colon = StringFind(json, ":", p);
    if(colon == -1) return "";
    int comma = StringFind(json, ",", colon);
    if(comma == -1) comma = StringFind(json, "}", colon);
    if(comma == -1) return "";
    string val = StringSubstr(json, colon+1, comma - colon - 1);
    StringReplace(val, "\"", "");
    val = Trim(val);
    return val;
}

//=== Xử lý tín hiệu JSON và mở lệnh
void ProcessSignal(string json)
{
    if(json=="") return;

    Print("📩 JSON read: ", json); // In ra JSON debug

    string symbol = GetJsonValue(json, "SYMBOL");
    string action = GetJsonValue(json, "ACTION");

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // Kiểm tra symbol trùng chart
    if(symbol != "" && symbol != _Symbol && symbol+"c" != _Symbol && symbol+"m" != _Symbol)
    {
        Print("⚠️ Bỏ qua tín hiệu vì SYMBOL=", symbol, " không khớp với chart: ", _Symbol);
        return;
    }

    // Mở lệnh
    if(action == "BUY")
    {
        Print("✅ Mở lệnh BUY: ", _Symbol, " LOT=", DefaultLot);
        Close();
        double lot = GetNextLot();
        trade.Buy(lot, _Symbol, 0, 0, 0, "EA Buy");
        PlaceBuyStops(lot);
    }
    else if(action == "SELL")
    {
        Print("✅ Mở lệnh SELL: ", _Symbol, " LOT=", DefaultLot);
        Close();
        double lot = GetNextLot();
        trade.Sell(lot, _Symbol, 0, 0, 0, "EA Sell");
        PlaceSellStops(lot);
    }
    else
    {
        Print("⚠️ Hành động không hợp lệ: ", action);
    }
}

void PlaceSellStops(double baseLot)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double lot = baseLot;

   for(int i=1; i<=10; i++)
   {
      double price = NormalizeDouble(bid + StepPrice * i, digits);

      lot = baseLot * MathPow(MultiplierLot, i);

      trade.SellLimit(lot, price, _Symbol, 0, 0, ORDER_TIME_GTC, 0,
                      "SellLimit " + IntegerToString(i));

      Print("📌 SellLimit ", i, ": ", price, " lot=", lot);
   }
}

void PlaceBuyStops(double baseLot)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double lot = baseLot;

   for(int i=1; i<=10; i++)
   {
      double price = NormalizeDouble(ask - StepPrice * i, digits);

      lot = baseLot * MathPow(MultiplierLot, i);

      trade.BuyLimit(lot, price, _Symbol, 0, 0, ORDER_TIME_GTC, 0,
                     "BuyLimit " + IntegerToString(i));

      Print("📌 BuyLimit ", i, ": ", price, " lot=", lot);
   }
}

double GetFirstOpenLot()
{
   datetime earliest = LONG_MAX;
   double lot = 0;

   for(int i=0;i<PositionsTotal();i++)
   {
      if(PositionGetTicket(i))
      {
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;

         datetime time = (datetime)PositionGetInteger(POSITION_TIME);

         if(time < earliest)
         {
            earliest = time;
            lot = PositionGetDouble(POSITION_VOLUME);
         }
      }
   }

   return lot;
}
double GetNextLot()
{
   
   if(PositionsTotal() > 0){
      return GetFirstOpenLot();
   }
   HistorySelect(0, TimeCurrent());

   ulong lastPositionID = 0;
   double totalProfit = 0;
   double lot = DefaultLot;

   for(int i = HistoryDealsTotal()-1; i >= 0; i--)
   {
      ulong deal = HistoryDealGetTicket(i);

      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;

      ulong posID = HistoryDealGetInteger(deal, DEAL_POSITION_ID);

      if(lastPositionID == 0)
         lastPositionID = posID;

      if(posID != lastPositionID)
         break;

      totalProfit += HistoryDealGetDouble(deal, DEAL_PROFIT);
      lot = HistoryDealGetDouble(deal, DEAL_VOLUME);
   }

   Print("Last position profit=", totalProfit);

   if(totalProfit < 0)
      return lot * Multiplier;
   else
      return DefaultLot;
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

int CountPositions(int type)
{
   int count = 0;

   for(int i=0;i<PositionsTotal();i++)
   {
      if(PositionGetTicket(i))
      {
         if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
            PositionGetInteger(POSITION_TYPE)==type)
            count++;
      }
   }
   return count;
}

void GetFirstTwoPositions(int type, ulong &ticket1, ulong &ticket2)
{
   datetime t1 = LONG_MAX, t2 = LONG_MAX;

   for(int i=0;i<PositionsTotal();i++)
   {
      if(!PositionGetTicket(i)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE)!=type) continue;

      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      ulong ticket = PositionGetInteger(POSITION_TICKET);

      if(t < t1)
      {
         t2 = t1;
         ticket2 = ticket1;

         t1 = t;
         ticket1 = ticket;
      }
      else if(t < t2)
      {
         t2 = t;
         ticket2 = ticket;
      }
   }
}

ulong GetLatestPositionTicket()
{
   datetime latest = 0;
   ulong ticket = 0;

   for(int i=0;i<PositionsTotal();i++)
   {
      if(PositionGetTicket(i))
      {
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;

         datetime t = (datetime)PositionGetInteger(POSITION_TIME);

         if(t > latest)
         {
            latest = t;
            ticket = PositionGetInteger(POSITION_TICKET);
         }
      }
   }

   return ticket;
}

void ManagePositions()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   ulong latestTicket = GetLatestPositionTicket();
   for(int i=0;i<PositionsTotal();i++)
   {
      if(!PositionGetTicket(i)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;

      ulong ticket = PositionGetInteger(POSITION_TICKET);
      if(ticket == latestTicket){
         continue; // ❌ Bỏ qua lệnh mới nhất
      }
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      long type = PositionGetInteger(POSITION_TYPE);

      // ================= BUY =================
      if(type == POSITION_TYPE_BUY)
      {
         double profitPrice = ask - openPrice;

         // ===== BE =====
         if(profitPrice >= BE_Price && (sl < openPrice || sl==0))
         {
            trade.PositionModify(ticket, openPrice, 0);
            Print("🔥 BUY BE: ", ticket);
         }

         // ===== TRAILING =====
         if(profitPrice >= BE_Price)
         {
            double newSL = ask - TrailStep;

            if(newSL > sl && newSL > openPrice)
            {
               trade.PositionModify(ticket, newSL, 0);
               Print("🚀 BUY TRAIL: ", ticket);
            }
         }
      }

      // ================= SELL =================
      if(type == POSITION_TYPE_SELL)
      {
         double profitPrice = openPrice - bid;

         // ===== BE =====
         if(profitPrice >= BE_Price && (sl > openPrice || sl==0))
         {
            trade.PositionModify(ticket, openPrice, 0);
            Print("🔥 SELL BE: ", ticket);
         }

         // ===== TRAILING =====
         if(profitPrice >= BE_Price)
         {
            double newSL = bid + TrailStep;

            if((newSL < sl || sl==0) && newSL < openPrice)
            {
               trade.PositionModify(ticket, newSL, 0);
               Print("🚀 SELL TRAIL: ", ticket);
            }
         }
      }
   }
}
void Close()
{
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
void OnInit()
{
    EventSetTimer(1);   // gọi OnTimer mỗi 1 giây
}

//=== OnTick
void OnTick()
{
    string content = ReadFileContent(FileName);
    if(content != "")
    {
        ProcessSignal(content);

        // Xóa file sau khi xử lý để tránh nhồi lệnh
        int clear = FileOpen(FileName, FILE_WRITE|FILE_TXT);
        if(clear != INVALID_HANDLE)
        {
            FileWrite(clear, "");
            FileClose(clear);
        }
    }
    ManagePositions();
}
void OnDeinit()
{
    EventKillTimer();
}