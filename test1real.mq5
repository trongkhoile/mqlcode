#property strict
#include <Trade/Trade.mqh>
CTrade trade;

input string FileName = "signals.txt";   // File chứa tín hiệu từ TradingView
input double DefaultLot = 0.2;          // Lot mặc định nếu file không có
input double TP_Pips = 5;               // TP tính theo pips
input double ALL_TP = 100; // tong TP
int result;
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


// Lấy ticket của lệnh đầu tiên cùng symbol
ulong GetFirstOrderTicket(string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
         if(PositionGetString(POSITION_SYMBOL) == symbol)
            return ticket;
   }
   return 0;
}

// Chỉnh TP của lệnh đầu về +5 hoặc -5 theo loại lệnh
void AdjustFirstOrderTP(double step, string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;

   ulong ticket = GetFirstOrderTicket(symbol);
   if(ticket == 0) return;

   if(PositionSelectByTicket(ticket))
   {
      int type   = PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = 0;

      if(type == POSITION_TYPE_BUY)
         tp = open + step;   // BUY → TP cao hơn
      else if(type == POSITION_TYPE_SELL)
         tp = open - step;   // SELL → TP thấp hơn

      trade.PositionModify(symbol, sl, tp);
   }
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

// Trả về:
//  1  -> Cùng hướng (cùng BUY hoặc cùng SELL)
//  0  -> Khác hướng (1 BUY - 1 SELL hoặc ngược lại)
// -1  -> Không đủ lệnh để so sánh (<=1 lệnh)

int CheckFirstLastOrderDirection()
{
   int total = PositionsTotal();
   if(total <= 1)
      return -1;   // Không đủ lệnh để so sánh

   // Lệnh đầu tiên mở
   ulong ticket_first = PositionGetTicket(0);
   if(!PositionSelectByTicket(ticket_first)) return -1;
   int type_first = (int)PositionGetInteger(POSITION_TYPE);

   // Lệnh cuối cùng mở
   ulong ticket_last = PositionGetTicket(total - 1);
   if(!PositionSelectByTicket(ticket_last)) return -1;
   int type_last = (int)PositionGetInteger(POSITION_TYPE);

   // So sánh
   if(type_first == type_last)
      return 1;   // Cùng hướng
   else
      return 0;   // Khác hướng
}
void CopyTPFromFirst()
{
   int total = PositionsTotal();
   if(total <= 1) return; // Không có gì để copy

   // Lấy TP của lệnh đầu tiên
   ulong ticket_first = PositionGetTicket(0);
   if(!PositionSelectByTicket(ticket_first)) return;
   double first_tp = PositionGetDouble(POSITION_TP);
   Print(first_tp);
   // Duyệt qua toàn bộ lệnh và set TP
   for(int i = 1; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         trade.PositionModify(ticket, sl, first_tp);
         trade.PositionModify(ticket, first_tp,tp);
      }
   }
}

string LastOrderType()
{
    int total = PositionsTotal(); // Số lệnh đang mở
    if(total == 0) return "NONE"; // Không có lệnh

    // Lấy lệnh cuối cùng (mới nhất) theo thứ tự trong danh sách
    ulong ticket = PositionGetTicket(total - 1);
    if(PositionSelectByTicket(ticket))
    {
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        if(type == POSITION_TYPE_BUY) return "BUY";
        else if(type == POSITION_TYPE_SELL) return "SELL";
    }

    return "NONE"; // Nếu không xác định được
}

void CopyTPFromLast(double total_risk, string symbol = NULL)
{
   int total = PositionsTotal();
   if(total <= 1) return; // Không có gì để copy
   // Duyệt qua toàn bộ lệnh và set TP
   double risk = total_risk;
   if (LastOrderType() == "BUY"){
      double risk = total_risk;
      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);
            trade.PositionModify(ticket, sl, risk-0.2);
            trade.PositionModify(ticket, risk,tp);
            Sleep(150);
         }
      }
   }
   else if (LastOrderType() == "SELL"){
      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);
            trade.PositionModify(ticket, sl, risk+0.2);
            trade.PositionModify(ticket, risk,tp);
            Sleep(150);
         }
      }
   }
}

double GetLastOrderOpenPrice(string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;

   int total = PositionsTotal();
   if(total == 0) return 0;   // Không có lệnh

   // Duyệt từ cuối về đầu để tìm lệnh cùng symbol
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == symbol)
         {
            return PositionGetDouble(POSITION_PRICE_OPEN);
         }
      }
   }

   return 0; // Không tìm thấy lệnh cùng symbol
}

double SumPriceDistanceLastOrderToAllBuy(string symbol=NULL)
{
   if(symbol==NULL) symbol = _Symbol;

   int total = PositionsTotal();
   if(total < 2) return 0;    // Không đủ lệnh để tính

   // --- Lấy lệnh cuối cùng của đúng symbol ---
   ulong last_ticket = 0;
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == symbol)
         {
            last_ticket = ticket;
            break;
         }
      }
   }

   if(last_ticket == 0) return 0; // Không có lệnh cùng symbol

   PositionSelectByTicket(last_ticket);
   double last_price = PositionGetDouble(POSITION_PRICE_OPEN);

   double sum_distance = 0;

   // --- Duyệt tất cả BUY để cộng khoảng cách ---
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == symbol &&
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            double buy_price = PositionGetDouble(POSITION_PRICE_OPEN);
            sum_distance += MathAbs(last_price - buy_price);
         }
      }
   }

   return sum_distance;
}

double SumPriceDistanceLastOrderToAllSell(string symbol=NULL)
{
   if(symbol==NULL) symbol = _Symbol;

   int total = PositionsTotal();
   if(total < 2) return 0;    // Không đủ lệnh để tính

   // --- Lấy lệnh cuối cùng của đúng symbol ---
   ulong last_ticket = 0;
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == symbol)
         {
            last_ticket = ticket;
            break;
         }
      }
   }
   if(last_ticket == 0) return 0; // Không có lệnh cùng symbol

   PositionSelectByTicket(last_ticket);
   double last_price = PositionGetDouble(POSITION_PRICE_OPEN);

   double sum_distance = 0;

   // --- Duyệt tất cả các lệnh để cộng khoảng cách ---
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == symbol &&
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            double sell_price = PositionGetDouble(POSITION_PRICE_OPEN);
            sum_distance += MathAbs(last_price - sell_price); // ✅ tính theo giá
         }
      }
   }

   return sum_distance; // trả về tổng khoảng cách theo giá thực
}

void RemoveAllTP_SL()
{
   int total = PositionsTotal();
   if(total <= 1) return; // Không có gì để copy
   // Duyệt qua toàn bộ lệnh và set TP
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         trade.PositionModify(ticket, 0,0);
         trade.PositionModify(ticket, 0,0);
      }
   }
}

void RemoveAllTP_SL1()
{
   int total = PositionsTotal();
   if(total <= 1) return; // Không có gì để copy
   // Duyệt qua toàn bộ lệnh và set TP
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         trade.PositionModify(ticket, 0,0);
         trade.PositionModify(ticket, 0,0);
      }
   }
}

int GetLastOrderType(string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;

   int total = PositionsTotal();
   if(total == 0) return -1; // Không có lệnh

   // Duyệt ngược từ lệnh cuối
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == symbol)
         {
            return (int)PositionGetInteger(POSITION_TYPE);
            // 0 = BUY, 1 = SELL
         }
      }
   }

   return -1; // Không có lệnh đúng symbol
}

ulong GetSecondOrderTicket(string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;

   int total = PositionsTotal();
   if(total <= 1) return 0;

   ulong first = GetFirstOrderTicket(symbol);
   ulong second_ticket = 0;
   datetime second_time = LONG_MAX;

   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
         if(ticket == first) continue;

         datetime t = (datetime)PositionGetInteger(POSITION_TIME);
         if(t < second_time)
         {
            second_time = t;
            second_ticket = ticket;
         }
      }
   }
   return second_ticket;
}
void SetFirstOrderTP(double step_points = 200.0)
{
   int total = PositionsTotal();
   if(total <= 0) return;

   ulong first_ticket = 0;
   datetime earliest = LONG_MAX;

   // Tìm lệnh mở sớm nhất
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         datetime opentime = (datetime)PositionGetInteger(POSITION_TIME);
         if(opentime < earliest)
         {
            earliest = opentime;
            first_ticket = ticket;
         }
      }
   }

   // Nếu không tìm được thì thoát
   if(first_ticket == 0) return;

   // Lấy thông tin lệnh đầu
   if(!PositionSelectByTicket(first_ticket)) return;

   int    type  = (int)PositionGetInteger(POSITION_TYPE);
   double open  = PositionGetDouble(POSITION_PRICE_OPEN);

   double tp = 0;

   // BUY → TP cao hơn giá mở
   // SELL → TP thấp hơn giá mở
   if(type == POSITION_TYPE_BUY)
      tp = open + 200;
   else if(type == POSITION_TYPE_SELL)
      tp = open - 200;
   else
      return;

   // Gửi lệnh chỉnh TP
   bool result = trade.PositionModify(first_ticket, 0, tp);

   if(result)
      Print("✅ TP lệnh đầu (", first_ticket, ") đã được chỉnh thành: ", tp);
   else
      Print("❌ Lỗi chỉnh TP lệnh đầu → Mã lỗi: ", _LastError);
}

double GetLastOrderLot()
{
   int total = PositionsTotal();
   if(total <= 0) return 0;

   ulong last_ticket = 0;
   datetime latest = 0;

   // Tìm lệnh mở sau cùng (TIME lớn nhất)
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         datetime opentime = (datetime)PositionGetInteger(POSITION_TIME);
         if(opentime > latest)
         {
            latest = opentime;
            last_ticket = ticket;
         }
      }
   }

   if(last_ticket == 0) return 0;

   // Chọn lệnh cuối và lấy lot
   if(PositionSelectByTicket(last_ticket))
      return PositionGetDouble(POSITION_VOLUME);

   return 0;
}

void SetFirstOrderSL(double total_risk, string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;

   int total = PositionsTotal();
   if(total <= 0) return;

   ulong first_ticket = 0;
   datetime earliest = LONG_MAX;

   // === Tìm lệnh mở sớm nhất ===
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) != symbol) continue;

         datetime opentime = (datetime)PositionGetInteger(POSITION_TIME);
         if(opentime < earliest)
         {
            earliest = opentime;
            first_ticket = ticket;
         }
      }
   }

   if(first_ticket == 0) return;
   if(!PositionSelectByTicket(first_ticket)) return;

   // Lấy TP hiện tại (để không thay đổi TP)
   double tp_old = PositionGetDouble(POSITION_TP);

   // Chỉnh SL = total_risk
   bool ok = trade.PositionModify(first_ticket, total_risk, tp_old);

   if(ok)
      Print("✅ SL lệnh đầu (", first_ticket, ") đã chỉnh thành: ", total_risk);
   else
      Print("❌ Lỗi chỉnh SL lệnh đầu → Mã lỗi: ", _LastError);
}

double GetTargetClosePrice(string symbol, double targetProfitUSD)
{
   double totalSellVolume = 0;
   double totalBuyVolume  = 0;
   double weightedSell = 0;
   double weightedBuy  = 0;

   // duyệt tất cả lệnh đang mở
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      long   type   = PositionGetInteger(POSITION_TYPE);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double price  = PositionGetDouble(POSITION_PRICE_OPEN);

      // Sell
      if(type == POSITION_TYPE_SELL)
      {
         totalSellVolume += volume;
         weightedSell += price * volume;
      }
      // Buy
      else if(type == POSITION_TYPE_BUY)
      {
         totalBuyVolume += volume;
         weightedBuy += price * volume;
      }
   }

   // Net Volume (lots)
   double netVolume = (totalSellVolume - totalBuyVolume); // >0 nghĩa là đang nghiêng SELL, <0 nghiêng BUY

   if(netVolume == 0)
   {
      Print("⚠ Không có vị thế ròng (Buy = Sell), không tính được TP.");
      return 0;
   }

   // giá trung bình ròng (giữ nguyên lot, không đổi oz)
   double netWeighted = (weightedSell - weightedBuy);

   // XAUUSD: mỗi 1 USD chênh lệch giá * 1 lot = 100$
   // nên phải chia 100 để quy ra USD vốn hóa tương ứng
   double P = (netWeighted*100 - targetProfitUSD) / (netVolume*100);

   return P;
}
/*
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Chỉ xử lý nếu có deal mới phát sinh
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) 
      return;

   if(trans.deal == 0 || !HistoryDealSelect(trans.deal))
      return;

   int deal_entry = (int)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

   // Chỉ xử lý nếu đây là lệnh thoát (đóng position)
   if(deal_entry != DEAL_ENTRY_OUT)
      return;

   // Lệnh vừa đóng
   ulong closed_ticket = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   if(closed_ticket == 0) return;
   // Lấy lệnh mở sớm nhất hiện tại (trước khi xử lý logic mới)
   ulong first_ticket_before = GetFirstOrderTicket();

   Print("✅ Lệnh mở sớm nhất vừa đóng → Bắt đầu xử lý logic...");

   // ====== Đến đây xác nhận đây là lệnh đầu đóng ======

   // Lệnh mở sớm thứ hai trở thành lệnh đầu mới
   ulong new_first = GetSecondOrderTicket();
   Print("🔄 Lệnh đầu mới = ", new_first);

   // Điều chỉnh TP của lệnh đầu mới +5 hoặc -5
   AdjustFirstOrderTP(5.0);

   // Xác định lệnh cuối đang mở là BUY hay SELL
   int type = GetLastOrderType();
   if(type == -1)
   {
      Print("⚠ Không còn lệnh nào → Dừng xử lý.");
      return;
   }

   int dir = CheckFirstLastOrderDirection();

   if(dir == 1) // cùng hướng
   {
      RemoveAllTP_SL();
      double total_risk = GetTargetClosePrice("XAUUSDm", TP_Pips*10);
      CopyTPFromLast(total_risk);
      Print("➡️  Lệnh đầu và lệnh cuối **CÙNG HƯỚNG** → Copy TP từ lệnh đầu.");
   }
   else if(dir == 0) // khác hướng
   {
      double sumSell = SumPriceDistanceLastOrderToAllSell();
      double sumBuy  = SumPriceDistanceLastOrderToAllBuy();
      double last    = GetLastOrderOpenPrice();
      double total_risk = 0;

      if(type == POSITION_TYPE_BUY)
         total_risk = GetTargetClosePrice("XAUUSDm", TP_Pips*10);
      else
         total_risk = GetTargetClosePrice("XAUUSDm", TP_Pips*10);
      Print(total_risk);
      RemoveAllTP_SL1();
      SetFirstOrderTP();
      SetFirstOrderSL(total_risk);
      CopyTPFromLast(total_risk);

      Print("🔄  Lệnh đầu và lệnh cuối **KHÁC HƯỚNG** → Set TP theo tổng risk.");
      Print("📊 Tổng khoảng cách BUY=", sumBuy, " SELL=", sumSell);
   }
   else
   {
      Print("⚠️  Không đủ lệnh để so sánh hướng.");
   }
}
*/

//=== Xử lý tín hiệu JSON và mở lệnh
void ProcessSignal(string json)
{
    if(json=="") return;
    
    Print("📩 JSON read: ", json); // In ra JSON debug

    string symbol = GetJsonValue(json, "SYMBOL");
    string action = GetJsonValue(json, "ACTION");

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double tp = TP_Pips ;
    double lot = GetLastOrderLot() + DefaultLot;
    // Kiểm tra symbol trùng chart
    if(symbol != "" && symbol != _Symbol && symbol+"m" != _Symbol && symbol+"c" != _Symbol  )
    {
        Print("⚠️ Bỏ qua tín hiệu vì SYMBOL=", symbol, " không khớp với chart: ", _Symbol);
        return;
    }

    // Mở lệnh
    if(action == "buy")
    {
         
        Print("✅ Mở lệnh BUY: ", _Symbol, " LOT=", lot);
        trade.Buy(lot, _Symbol, 0, 0, 0, "EA Buy");
    }
    else if(action == "sell")
    {
        Print("✅ Mở lệnh SELL: ", _Symbol, " LOT=", lot);
        trade.Sell(lot, _Symbol, 0, 0, 0, "EA Sell");
    }
    else
    {
        Print("⚠️ Hành động không hợp lệ: ", action);
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
}

//=== OnTick
void OnTick()
{
    if(TotalFloatingProfit() >= ALL_TP){
      Close();
    }
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
}
