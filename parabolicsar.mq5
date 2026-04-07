//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots 1

#property indicator_type1 DRAW_ARROW
#property indicator_color1 clrDeepSkyBlue
#property indicator_width1 2
#property indicator_label1 "Custom SAR"

input double Start = 0.05;
input double Increment = 0.005;
input double MaxValue = 0.2;

double SARBuffer[];

double af[];
double ep[];
bool trendUp[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0,SARBuffer,INDICATOR_DATA);
   PlotIndexSetInteger(0,PLOT_ARROW,159);

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{

   ArrayResize(af,rates_total);
   ArrayResize(ep,rates_total);
   ArrayResize(trendUp,rates_total);

   trendUp[0] = true;
   SARBuffer[0] = low[0];
   ep[0] = high[0];
   af[0] = Start;

   for(int i=1;i<rates_total;i++)
   {

      SARBuffer[i] = SARBuffer[i-1] + af[i-1]*(ep[i-1]-SARBuffer[i-1]);

      if(trendUp[i-1])
      {
         if(low[i] < SARBuffer[i])
         {
            trendUp[i] = false;
            SARBuffer[i] = ep[i-1];
            ep[i] = low[i];
            af[i] = Start;
         }
         else
         {
            trendUp[i] = true;

            if(high[i] > ep[i-1])
            {
               ep[i] = high[i];
               af[i] = MathMin(af[i-1] + Increment, MaxValue);
            }
            else
            {
               ep[i] = ep[i-1];
               af[i] = af[i-1];
            }
         }
      }
      else
      {
         if(high[i] > SARBuffer[i])
         {
            trendUp[i] = true;
            SARBuffer[i] = ep[i-1];
            ep[i] = high[i];
            af[i] = Start;
         }
         else
         {
            trendUp[i] = false;

            if(low[i] < ep[i-1])
            {
               ep[i] = low[i];
               af[i] = MathMin(af[i-1] + Increment, MaxValue);
            }
            else
            {
               ep[i] = ep[i-1];
               af[i] = af[i-1];
            }
         }
      }

   }

   return(rates_total);
}