//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

CTrade trade;

// Input
input int Kperiod = 55;
input int Dperiod = 5;
input int Slowing = 13;
input double Overbought = 90; // Điểm chạm Stoch
input double Oversold   = 10; // Điểm chạm Stoch
input ENUM_MA_METHOD MaMethod = MODE_SMA;
input bool Nennhanchim = true; // Nến nhấn chìm         
input bool Nensaobang = true;// Nến sao băng   
input bool NenDoji = true;// Nến doji     
input string BotToken = "8577816937:AAFPSCYCb2pjKJ__74mbMFbTQattCCM1HDY"; // Token
input string ChatID   = "6487663759";// Chat ID                
datetime lastBarTime = 0;
// Biến lưu handle
int stochHandle;

// Buffer
double Kbuffer[];
double Dbuffer[];

//+------------------------------------------------------------------+
int OnInit()
{
   stochHandle = iStochastic(_Symbol, PERIOD_CURRENT, Kperiod, Dperiod, Slowing, MaMethod, STO_LOWHIGH);
   
   if(stochHandle == INVALID_HANDLE)
   {
      Print("Không tạo được Stochastic!");
      return(INIT_FAILED);
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
      // Lấy thời gian nến hiện tại
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);

   // Nếu chưa có nến mới → bỏ qua
   if(currentBarTime == lastBarTime) return;

   // Có nến mới → cập nhật
   lastBarTime = currentBarTime;
   if(CopyBuffer(stochHandle, 0, 0, 3, Kbuffer) < 0) return;
   if(CopyBuffer(stochHandle, 1, 0, 3, Dbuffer) < 0) return;

   double K_now = Kbuffer[1];
   double K_prev = Kbuffer[2];

   double D_now = Dbuffer[1];
   double D_prev = Dbuffer[2];
   if(IsDoji() && NenDoji == true){
      Notify("Nen Doji");
   }
      // Chạm vùng quá bán (<=10)
   // Vừa chạm vùng quá bán
   if(K_prev <= Oversold && K_now > Oversold)
   {
      Notify("Stoch vua cham: " + DoubleToString(Oversold, 1));
   }
   
   // Vừa chạm vùng quá mua
   if(K_prev >= Overbought && K_now < Overbought)
   {
      Notify("Stoch vua cham: " + DoubleToString(Overbought, 1));
   }
   if(IsBullishEngulfing() && Nennhanchim == true){
      Notify("Nen nhan chim");
   }
   if(IsShootingStar() && Nensaobang== true){
      Notify("Nen sao bang");
   }
   if(IsBearishEngulfing() && Nennhanchim == true){
      Notify("Nen nhan chim");
   }
   // BUY: K cắt lên D
   if(K_prev > D_prev && K_now < D_now)
   {
      Notify("Stoch cắt lên");
   }

   // SELL: K cắt xuống D
   if(K_prev < D_prev && K_now > D_now)
   {
      Notify("Stoch cắt xuống");
   }
}
//+------------------------------------------------------------------+
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
 
bool IsBullishEngulfing()
{
   double open1  = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);

   double open2  = iOpen(_Symbol, PERIOD_CURRENT, 2);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double high2  = iHigh(_Symbol, PERIOD_CURRENT, 2);
   double low2   = iLow(_Symbol, PERIOD_CURRENT, 2);

   if(close2 < open2 &&        // nến trước giảm
      close1 > open1 &&        // nến sau tăng
      open1 < low2 &&          // 🔥 mở dưới cả đáy
      close1 > high2)          // 🔥 đóng vượt cả đỉnh
      return true;

   return false;
}

//--------------------------------------------

bool IsBearishEngulfing()
{
   double open1  = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);

   double open2  = iOpen(_Symbol, PERIOD_CURRENT, 2);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double high2  = iHigh(_Symbol, PERIOD_CURRENT, 2);
   double low2   = iLow(_Symbol, PERIOD_CURRENT, 2);

   if(close2 > open2 &&        // nến trước tăng
      close1 < open1 &&        // nến sau giảm
      open1 > high2 &&         // 🔥 mở trên đỉnh
      close1 < low2)           // 🔥 đóng dưới đáy
      return true;

   return false;
}
bool IsShootingStar()
{
   double open  = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double close = iClose(_Symbol, PERIOD_CURRENT, 1);
   double high  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low   = iLow(_Symbol, PERIOD_CURRENT, 1);

   double body = MathAbs(close - open);
   double upperWick = high - MathMax(open, close);
   double lowerWick = MathMin(open, close) - low;

   // tránh chia cho 0
   if(body == 0) return false;

   if(
      upperWick >= 2 * body &&   // râu trên dài
      lowerWick <= body * 0.3    // râu dưới ngắn
     )
      return true;

   return false;
}

bool IsDoji()
{
   double open  = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double close = iClose(_Symbol, PERIOD_CURRENT, 1);
   double high  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low   = iLow(_Symbol, PERIOD_CURRENT, 1);

   double body = MathAbs(close - open);
   double range = high - low;

   if(range == 0) return false;

   // thân <= 10% toàn nến
   if(body <= range * 0.1)
      return true;

   return false;
}