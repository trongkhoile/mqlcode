#property strict
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
CPositionInfo m_position;
CTrade trade;
ulong startTime; // To store the start time for performance measurement
CTrade sTrade; // Trade object used for operations
// ====== PANEL CONFIG ======
#define PANEL_NAME   "INFO_PANEL"
#define PANEL_X      260
#define PANEL_Y      20
#define PANEL_W      260
#define PANEL_H      260

color BG_COLOR   = clrBlack;
color BORDER_CLR = clrAqua;
//===================== CÀI ĐẶT CHUNG =====================
input double   Spread = 0.3; // Spread của tài khoản
input bool     EnableBuy          = true;  // Bật/tắt chiều Buy
input bool     EnableSell         = true;  // Bật/tắt chiều Sell
input double   FirstLotBuy        = 0.01;  // Lot đầu Buy
input double   FirstLotSell       = 0.01;  // Lot đầu Sell

//===================== MENU CHỐT LỜI TỔNG =====================
input double   TotalProfitTarget  = 10;      // Số tiền chốt lời tổng ($)
input double   TotalLossCut       = -100000.0;   // Cắt lỗ theo số tiền ($)

//===================== CÀI ĐẶT DCA DƯƠNG =====================
input bool     EnableDcaDuong     = true;        // Bật/tắt DCA dương
input double   DcaDistancePip_D   = 300.0;       // Khoảng cách DCA Dương (Pip)
input double   DcaMultiplier_D    = 2;         // Hệ số nhân lot DCA Dương

//===================== CÀI ĐẶT DCA ÂM =====================
input bool     EnableDcaAm        = true;        // Bật/tắt DCA âm
input double   DcaDistancePip_A   = 300.0;       // Khoảng cách DCA Âm (Pip)
input double   DcaMultiplier_A    = 2;         // Hệ số nhân lot DCA Âm

//===================== CÀI ĐẶT HEDGING =====================
input bool     EnableHedging      = true;        // Bật/tắt Hedging
input double   HedgingDDTrigger   = -2000.0;     // Hedging khi mức DD đạt ($)
input string BotToken = "8577816937:AAFPSCYCb2pjKJ__74mbMFbTQattCCM1HDY"; // Token
input string ChatID   = "6487663759";                                     // Chat ID 
double priceDCA_duong_Buy;
double priceDCA_duong_Sell;
double priceDCA_am_Buy;
double priceDCA_am_Sell;
double lotDCA_duong_buy, lotDCA_am_buy, lotDCA_duong_sell, lotDCA_am_sell;
int buyCnt=0, sellCnt=0;
double buyLot=0, sellLot=0;
double profitBuy=0, profitSell=0;
double totalProfit=0;
int check = 0;
double equityPeak     = 0.0;
double maxDrawdown    = 0.0;
double currentDD      = 0.0;
datetime lastLicenseCheck = 0;
int licenseCheckInterval = 30; // kiểm tra mỗi 30 giây
bool licenseValid = true;
bool licenseCheckedToday = false;

int OnInit()
  {
//---
   
//---
   Print("LICENSE OK");
   Notify("Bot da khoi tao thanh cong");
   DeleteAllObjects();
   CreateLabel("L0", 10, clrBlue);
   CreateLabel("L1", 40, clrLime);
   CreateLabel("L2", 60, clrRed);
   CreateLabel("L12", 90, clrOrange);
   CreateLabel("L4", 120, clrWhite);
   CreateLabel("L5", 140, clrWhite);
   CreateLabel("L7", 170, clrLime);
   CreateLabel("L8", 190, clrRed);
   CreateLabel("L10",240, clrWhite);
   CreateLabel("L11", 220, clrOrange);
         // Nếu đang backtest thì bỏ qua license
   if(MQLInfoInteger(MQL_TESTER))
   {
      Print("Tester mode - Skip license check");
      return(INIT_SUCCEEDED);
   }
   if(!CheckLicense())
   {
      Print("LICENSE INVALID");
      return(INIT_FAILED);
   }
   return INIT_SUCCEEDED;
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
      // ===== CHECK LICENSE ĐỊNH KỲ =====
   // ===== CHECK LICENSE 5h – 6h sáng VN =====
   // ===== CHECK LICENSE 05:30 – 05:45 VN =====
   CheckNewDay();
   UpdatePanel(); 
   UpdateDrawdown();
   datetime serverTime = TimeCurrent();
   datetime vnTime     = serverTime + 7 * 3600;
   
   MqlDateTime t;
   TimeToStruct(vnTime, t);
   
   // Reset mỗi ngày
   static int lastDay = -1;
   if(lastDay != t.day)
   {
      lastDay = t.day;
      licenseCheckedToday = false;
   }
   
   // Check trong khung 05:30–05:45
   if(t.hour == 5 && t.min >= 30 && t.min <= 45 && !licenseCheckedToday && !MQLInfoInteger(MQL_TESTER))
   {
      licenseCheckedToday = true;
   
      Print("Dang kiem tra license (05:30–05:45)");
   
      if(!CheckLicense())
      {
         Print("LICENSE REMOVED → STOP BOT");
         Notify("License bi xoa → Bot dung hoat dong");
   
         Close();
         ExpertRemove();
         return;
      }
   }
   if(PositionsTotal() == 0)
   {
      check = 0;
      double priceBuy  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      priceDCA_duong_Buy = priceBuy;
      priceDCA_am_Buy  = priceBuy;
      double slBuy     = 0;
      double tpBuy     = 0;
      double priceSell = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      priceDCA_duong_Sell = priceSell;
      priceDCA_am_Sell = priceSell;
      double slSell    = 0;
      double tpSell    = 0;
      if(EnableBuy == true){
         trade.Buy(FirstLotBuy, _Symbol, priceBuy, 0, 0, "DCA_AM_BUY");
         lotDCA_duong_buy = FirstLotBuy;
         lotDCA_am_buy = FirstLotBuy;
      }
      if(EnableSell == true){
         trade.Sell(FirstLotSell, _Symbol, priceSell, 0, 0, "DCA_AM_SELL");
         lotDCA_am_sell = FirstLotSell;
         lotDCA_duong_sell = FirstLotSell;
      }
      //double total_risk = GetTargetClosePrice( _Symbol, TotalProfitTarget);
      //RemoveAllTP_SL1();
      //CopyTPFromLast(total_risk);
   }
   if(EnableHedging == true && check == 0){
      CheckHedging();
   }
   if(EnableDcaDuong == true && check == 0){
      if(EnableBuy == true){
         CheckDCADuongBuy();
      }
      if(EnableSell == true && check == 0){
         CheckDCADuongSell();
      }
   }
   if(EnableDcaAm == true && check == 0){
      if(EnableBuy == true){
         CheckDCAAmBuy();
      }
      if(EnableSell == true && check == 0){
         CheckDCAAmSell();
      }
   }
   if(TotalFloatingProfit() >= TotalProfitTarget){
      Close();
   }
   if(TotalFloatingProfit() <= TotalLossCut){
      Close();
   }
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   ObjectSetString(0,"LBL_BAL",OBJPROP_TEXT,"Balance: " + DoubleToString(balance,2));
   ObjectSetString(0,"LBL_EQ", OBJPROP_TEXT,"Equity : "  + DoubleToString(equity,2));
}
//+------------------------------------------------------------------+
// ====== CREATE PANEL ======
void CreatePanel()
{
   if(ObjectFind(0, PANEL_NAME) >= 0) return;

   ObjectCreate(0, PANEL_NAME, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_XDISTANCE, PANEL_X);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_YDISTANCE, PANEL_Y);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_XSIZE, PANEL_W);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_YSIZE, PANEL_H);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_COLOR, BORDER_CLR);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_BGCOLOR, BG_COLOR);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
}

void CreateLabel(string name,int y,color clr)
{
   ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,PANEL_X+10);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,PANEL_Y+y);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);
   ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
}

// ====== UPDATE PANEL ======
void UpdatePanel()
{
   int buyCount, sellCount;
   double buyLot, sellLot;
   double profitBuy, profitSell, floating;
   string accText = "Acc ID      : " 
               + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) ;
   GetOpenPositionsInfo(
      buyCount,
      sellCount,
      buyLot,
      sellLot,
      profitBuy,
      profitSell,
      floating
   );

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

   SetText("L0"," --- LinhBG-TraderU40 ---", clrBlanchedAlmond);

   SetText("L1","▲ Buy       : "+buyCount+" orders ("+DoubleToString(buyLot,2)+" lots)", clrLime);
   SetText("L2","▼ Sell      : "+sellCount+" orders ("+DoubleToString(sellLot,2)+" lots)", clrRed);

   SetText("L7","Profit Buy  : "+DoubleToString(profitBuy,2)+"$", profitBuy>=0 ? clrLime : clrRed);
   SetText("L8","Profit Sell : "+DoubleToString(profitSell,2)+"$", profitSell>=0 ? clrLime : clrRed);
   SetText("L11","Max DD      : " + DoubleToString(maxDrawdown, 2) + "$",maxDrawdown >= 0 ? clrLime : clrRed);
   SetText(
      "L10",
      "Floating P/L: "+DoubleToString(floating,2)+"$",
      floating >= 0 ? clrLime : clrRed
   );
   SetText("L12",accText, clrOrange);
   SetText("L4","Balance     : "+DoubleToString(balance,2)+"$", clrWhite);
   SetText("L5","Equity      : "+DoubleToString(equity,2)+"$", clrWhite);
}

string GetAccountType()
{
   string server = AccountInfoString(ACCOUNT_SERVER);

   if(StringFind(server, "Cent")      >= 0) return "Cent";
   if(StringFind(server, "Standard")  >= 0) return "Standard";
   if(StringFind(server, "ECN")       >= 0) return "ECN";
   if(StringFind(server, "Pro")       >= 0) return "Pro";

   return "Live";
}

void GetOpenPositionsInfo(
   int &buyCount,
   int &sellCount,
   double &buyLot,
   double &sellLot,
   double &profitBuy,
   double &profitSell,
   double &totalFloating
)
{
   buyCount = 0;
   sellCount = 0;
   buyLot = 0.0;
   sellLot = 0.0;
   profitBuy = 0.0;
   profitSell = 0.0;
   totalFloating = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      int type = (int)PositionGetInteger(POSITION_TYPE);
      double lot = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT);

      totalFloating += profit;

      if(type == POSITION_TYPE_BUY)
      {
         buyCount++;
         buyLot += lot;
         profitBuy += profit;
      }
      else if(type == POSITION_TYPE_SELL)
      {
         sellCount++;
         sellLot += lot;
         profitSell += profit;
      }
   }
}


// ====== SET TEXT ======
void SetText(string name,string text,color clr)
{
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
}


void DeleteAllObjects()
{
   int total = ObjectsTotal(0, -1, -1);  // chart hiện tại
   
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, -1, -1);
      ObjectDelete(0, name);
   }
}


void CheckDCADuongBuy()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double PipPerPrice   = PipValue();
   // Duyệt tất cả lệnh đang mở trước để lấy ticket
   double diff_price = ask - priceDCA_duong_Buy;
   double need_price = DcaDistancePip_D*PipPerPrice; // => số giá cần tăng
   if(diff_price >= need_price)
   {
      double newLot = NormalizeDouble(lotDCA_duong_buy * DcaMultiplier_D, 2);
      // Mở lệnh mới cùng comment
      trade.Buy(newLot, _Symbol, ask, 0, 0, "DCA_DUONG_BUY");
      lotDCA_duong_buy = lotDCA_duong_buy * DcaMultiplier_D;
      priceDCA_duong_Buy = ask;
   }
}

void CheckDCADuongSell()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double PipPerPrice   = PipValue();  // 1 pip = 0.01 với XAUUSD
   double diff_price = priceDCA_duong_Sell - bid;
   double need_price = DcaDistancePip_D*PipPerPrice; // số giá cần giảm
   if(diff_price >= need_price)
   {
      double newLot = NormalizeDouble(lotDCA_duong_sell * DcaMultiplier_D, 2);
      trade.Sell(newLot, _Symbol, bid, 0, 0, "DCA_DUONG_SELL");
      lotDCA_duong_sell = lotDCA_duong_sell * DcaMultiplier_D;
      priceDCA_duong_Sell = bid;
   }
}

void CheckDCAAmBuy()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double PipPerPrice = PipValue();

   double diff_price = priceDCA_am_Buy - ask; // GIÁ GIẢM
   double need_price = DcaDistancePip_A * PipPerPrice;

   if(diff_price >= need_price)
   {
      double newLot = NormalizeDouble(lotDCA_am_buy * DcaMultiplier_A, 2);
      trade.Buy(newLot, _Symbol, ask, 0, 0, "DCA_AM_BUY");

      lotDCA_am_buy   = lotDCA_am_buy * DcaMultiplier_A;
      priceDCA_am_Buy = ask;
   }
}

void CheckDCAAmSell()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double PipPerPrice = PipValue();

   double diff_price = bid - priceDCA_am_Sell; // GIÁ TĂNG
   double need_price = DcaDistancePip_A * PipPerPrice;

   if(diff_price >= need_price)
   {
      double newLot = NormalizeDouble(lotDCA_am_sell * DcaMultiplier_A, 2);
      trade.Sell(newLot, _Symbol, bid, 0, 0, "DCA_AM_SELL");
      lotDCA_am_sell   = lotDCA_am_sell * DcaMultiplier_A;
      priceDCA_am_Sell = bid;
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


double PipValue()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // Forex 5 hoặc 3 digits (EURUSD, USDJPY)
   if(digits == 5 || digits == 3)
      return SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;

   // XAUUSD, chỉ số, crypto
   return SymbolInfoDouble(_Symbol, SYMBOL_POINT);
}

void BuyAsync(double volume)
  {
//--- prepare the request
   MqlTradeRequest req={};
   req.action      =TRADE_ACTION_DEAL;
   req.symbol      =_Symbol;
   req.magic       =12345;
   req.volume      =0.1;
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
void SellAsync(double volume)
  {
//--- prepare the request
   MqlTradeRequest req={};
   req.action      =TRADE_ACTION_DEAL;
   req.symbol      =_Symbol;
   req.magic       =12345;
   req.volume      =0.1;
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
  
double NormalizeLot(double lot)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathMax(lot, minLot);
   lot = MathMin(lot, maxLot);

   return MathFloor(lot / stepLot) * stepLot;
}

void GetTotalLots(double &buyLot, double &sellLot)
{
   buyLot  = 0.0;
   sellLot = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double lot = PositionGetDouble(POSITION_VOLUME);
      int type   = (int)PositionGetInteger(POSITION_TYPE);

      if(type == POSITION_TYPE_BUY)
         buyLot += lot;
      else if(type == POSITION_TYPE_SELL)
         sellLot += lot;
   }
}

void CheckHedging()
{
   if(!EnableHedging) return;

   double floating = TotalFloatingProfit();
   if(floating > HedgingDDTrigger) return;

   double buyLot, sellLot;
   GetTotalLots(buyLot, sellLot);
   
   double diffLot = NormalizeLot(MathAbs(buyLot - sellLot));
   if(diffLot <= 0) return;

   // Nếu BUY nhiều hơn → hedge bằng SELL
   if(buyLot > sellLot)
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      trade.Sell(diffLot, _Symbol, price, 0, 0, "HEDGE_SELL");
      check = 1;
      Print("HEDGING SELL: ", diffLot);
      Alert("Chú ý: Có tín hiệu xuất hiện!");
      PlaySound("alert.wav");
      Comment("Có tín hiệu xuất hiện!");

      string msg = "Bot da kich hoat chuc nang Hedging";
      Notify("Bot da kich hoat chuc nang Hedging");
      string file = TakeChartScreenshot();
      if(file != "")
      {
         SendTelegramPhoto(BotToken, ChatID, file, "Active");
      }
   }
   // Nếu SELL nhiều hơn → hedge bằng BUY
   else if(sellLot > buyLot)
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      trade.Buy(diffLot, _Symbol, price, 0, 0, "HEDGE_BUY");
      check = 1;
      Print("HEDGING BUY: ", diffLot);
      Alert("Chú ý: Có tín hiệu xuất hiện!");
      PlaySound("alert.wav");
      Comment("Có tín hiệu xuất hiện!");

      string msg = "Bot da kich hoat chuc nang Hedging";
                   
      Notify("Bot da kich hoat chuc nang Hedging");
      string file = TakeChartScreenshot();
      if(file != "")
      {
         SendTelegramPhoto(BotToken, ChatID, file, "Active");
      }
   }
   Print(diffLot);
}

// Gửi Telegram bằng GET URL
bool SendTelegram(string botToken, string chatID, string msg)
 {
   string url = "https://api.telegram.org/bot"+botToken+"/sendMessage?chat_id="+chatID+"&text="+URLEncodeASCII(msg);

   char post[];
   char result[];
   string result_headers;

   ResetLastError();
   int res = WebRequest("GET", url, "", 5000, post, result, result_headers);

   Print("Telegram URL: ", url);
   Print("WebRequest res = ", res, " LastError = ", GetLastError());
   Print("Result body: ", CharArrayToString(result));

   return (res==200);
}
  
void Notify(string msg)
{
   Alert(msg);
   Comment(msg);
   PlaySound("alert.wav");
   if(!SendTelegram(BotToken, ChatID, msg))
      Print("⚠️ Telegram send failed!");
}

// Encode tin nhắn ASCII cho URL
string URLEncodeASCII(string msg)
  {
   string enc = "";
   for(int i=0; i<StringLen(msg); i++)
     {
      string c = StringSubstr(msg, i, 1); // lấy ký tự i-th
      ushort code = msg[i];

      if(code>=32 && code<=126)       // ASCII hiển thị
         enc += c;
      else
         if(code=='\n')             // xuống dòng
            enc += "%0A";
         else                             // encode %XX
            enc += "%" + StringFormat("%02X", code & 0xFF);
     }
   return enc;
  }

string TakeChartScreenshot()
{
   string fileName = "chart.png";
   ChartRedraw();
   Sleep(500);
   bool ok = ChartScreenShot(0, "chart.png", 1280, 720, ALIGN_RIGHT);
   if(!ok)
   {
      Print("❌ Chụp màn hình thất bại");
      return "";
   }

   return fileName;
}

bool SendTelegramPhoto(string botToken, string chatID, string fileName, string caption="")
{
   string boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW";
   string url = "https://api.telegram.org/bot" + botToken + "/sendPhoto";

   // 1️⃣ MỞ FILE ẢNH
   int fileHandle = FileOpen(fileName, FILE_READ | FILE_BIN);
   if(fileHandle == INVALID_HANDLE)
   {
      Print("❌ Không mở được file ảnh: ", fileName,
            " err=", GetLastError());
      return false;
   }

   int fileSize = (int)FileSize(fileHandle);
   uchar image[];
   ArrayResize(image, fileSize);
   FileReadArray(fileHandle, image);
   FileClose(fileHandle);

   // 2️⃣ HEADER BODY
   string head =
      "--" + boundary + "\r\n"
      "Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n" +
      chatID + "\r\n" +

      "--" + boundary + "\r\n"
      "Content-Disposition: form-data; name=\"caption\"\r\n\r\n" +
      caption + "\r\n" +

      "--" + boundary + "\r\n"
      "Content-Disposition: form-data; name=\"photo\"; filename=\"" + fileName + "\"\r\n"
      "Content-Type: image/png\r\n\r\n";

   string tail = "\r\n--" + boundary + "--\r\n";

   // 3️⃣ GHÉP BODY
   uchar post[];
   StringToCharArray(head, post);
   int pos = ArraySize(post) - 1;   // ❗ bỏ null char

   ArrayResize(post, pos + ArraySize(image));
   ArrayCopy(post, image, pos);

   uchar tailArr[];
   StringToCharArray(tail, tailArr);
   int tailSize = ArraySize(tailArr) - 1;

   int oldSize = ArraySize(post);
   ArrayResize(post, oldSize + tailSize);
   ArrayCopy(post, tailArr, oldSize, 0, tailSize);

   // 4️⃣ HEADER HTTP (CHUẨN)
   string request_headers =
      "Content-Type: multipart/form-data; boundary=" + boundary;

   char result[];
   string response_headers;

   ResetLastError();
   int res = WebRequest(
      "POST",
      url,
      request_headers,
      20000,
      post,
      result,
      response_headers
   );

   Print("📨 Telegram photo res=", res,
         " err=", GetLastError(),
         " body=", CharArrayToString(result));

   return (res == 200);
}

void UpdateDrawdown()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   // Lần đầu hoặc equity lập đỉnh mới
   if(equity > equityPeak || equityPeak == 0)
   {
      equityPeak = equity;
   }
   else
   {
      currentDD = equity - equityPeak;
      if(currentDD < maxDrawdown)
         maxDrawdown = currentDD;
   }
}


void OnTradeTransaction(
   const MqlTradeTransaction& trans,
   const MqlTradeRequest& request,
   const MqlTradeResult& result)
{
   // Chỉ xử lý khi có DEAL mới
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   // Select deal
   if(!HistoryDealSelect(trans.deal))
      return;

   int entry = (int)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   int type  = (int)HistoryDealGetInteger(trans.deal, DEAL_TYPE);

   double volume = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);

   // ===== KHI ĐÓNG LỆNH =====
   if(entry == DEAL_ENTRY_OUT)
   {
      totalProfit += profit;
      if(type == DEAL_TYPE_BUY)
      {
         profitBuy += profit;
      }
      else if(type == DEAL_TYPE_SELL)
      {
         profitSell += profit;
      }
   }

   // ===== KHI VÀO LỆNH =====
   if(entry == DEAL_ENTRY_IN)
   {
      if(type == DEAL_TYPE_BUY)
      {
         buyLot += volume;
         buyCnt++;
      }
      else if(type == DEAL_TYPE_SELL)
      {
         sellLot += volume;
         sellCnt++;
      }
   }
}

bool IsTradingTimeVN()
{
   datetime serverTime = TimeCurrent();
   datetime vnTime     = serverTime + 7 * 3600; // GMT+7

   MqlDateTime t;
   TimeToStruct(vnTime, t);

   int hour = t.hour;

   // ❌ Cấm vào lệnh từ 01:00 → 06:59 giờ VN
   if(hour >= 1 && hour < 7)
      return false;

   return true;
}

void CheckNewDay()
{
   static int lastDay = -1;

   datetime serverTime = TimeCurrent();
   datetime vnTime     = serverTime + 7 * 3600;

   MqlDateTime t;
   TimeToStruct(vnTime, t);

   if(lastDay != t.day)
   {
      lastDay = t.day;

      equityPeak  = AccountInfoDouble(ACCOUNT_EQUITY);
      maxDrawdown = 0.0;
      currentDD   = 0.0;

      Print("===== NEW DAY → RESET DAILY DD =====");
   }
}

bool CheckLicense()
{
   string url = "https://script.google.com/macros/s/AKfycbwd5jZw7TR85SIoLEGbFVBTtghDfxfuIp-IwDzdDMlo8obJtKemwdfpbp6NYt2CE9oV/exec?acc=" 
                + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   Print(url);
   char post[];
   char result[];
   string headers;
   string result_headers;

   int timeout = 5000;

   ResetLastError();

   int res = WebRequest(
      "GET",
      url,
      headers,
      timeout,
      post,          // 👈 bắt buộc phải có
      result,
      result_headers
   );

   if(res == -1)
   {
      Print("WebRequest error: ", GetLastError());
      return false;
   }

   string response = CharArrayToString(result);

   Print("Server response: ", response);

   if(StringFind(response, "OK") >= 0)
      return true;

   return false;
}

