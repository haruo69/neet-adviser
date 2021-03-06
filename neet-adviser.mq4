//+------------------------------------------------------------------+
//|                                                 neet-adviser.mq4 |
//|                                          Copyright 2017, haruo69 |
//|                                                   http://neat.jp |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, haruo69"
#property link      "http://neat.jp"
#property version   "1.00"
#property strict

//変数の宣言
extern int Magic         = 1122;
extern int FMA_Period    = 12; //短期移動平均線の計算期間
extern int SMA_Period    = 26; //長期移動平均線の計算期間
extern int MA_Mode       = 1;  //使用する移動平均線の種類を示す整数値
extern int Applied_price = 0;  //移動平均線の計算に使用する価格データの種類を示す整数値
extern double Lots       = 0.1;//取引するロットサイズ(1000通貨)
extern int Slippage      = 10; //許容スリッページ数
extern string Comments   = "NEET Adviser";

double FMA_1 = 0; //１本前のバーの短期移動平均線の値
double FMA_2 = 0; //２本前のバーの短期移動平均線の値
double SMA_1 = 0; //１本前のバーの長期移動平均線の値
double SMA_2 = 0; //２本前のバーの長期移動平均線の値

double MacdCurrent    = 0; //現在のMACD線の値
double MacdPrevious   = 0; //１本前のMACD線の値
double SignalCurrent  = 0; //現在のシグナル線の値
double SignalPrevious = 0; //１本前のシグナル線の値

int Ticket = 0; //エントリー注文が約定した際に、ポジションに付される整数値（＝チケット番号）

int Adjusted_Slippage = 0; //AdjustSlippage()関数（後述）によって調整された許容スリッページ数
int Calculated_Slippage = 0;

datetime Bar_Time = 0; //バーの形成開始時刻

bool Closed = false; //決済注文が約定したか否かの結果 | 約定した場合は「true」を、約定しなかった場合は「false」

//関数の定義
int AdjustSlippage(string Currency, int Slippage_Pips)
{
   int Symbol_Digits = MarketInfo(Currency, MODE_DIGITS);
   if(Symbol_Digits == 2 || Symbol_Digits == 4)
   {
      Calculated_Slippage = Slippage_Pips;
   }
   else if(Symbol_Digits == 3 || Symbol_Digits == 5)
   {
      Calculated_Slippage = Slippage_Pips * 10;
   }
   
   return(Calculated_Slippage);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   Adjusted_Slippage = AdjustSlippage(Symbol(), Slippage);
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
   //バーの数が長期MA期間よりも短ければ処理を止める
   if(Bars < SMA_Period)
   {
      return;
   }
   
   //始値か否かのチェック
   if(Bar_Time == Time[0])
   {
      return;
   }
   else if(Bar_Time != Time[0])
   {
      Bar_Time = Time[0];
   }
   
   //インジケーターの値の計算
   FMA_1 = iMA(Symbol(), 0, FMA_Period, 0, MA_Mode, Applied_price, 1);
   FMA_1 = NormalizeDouble(FMA_1, MarketInfo(Symbol(), MODE_DIGITS));
   FMA_2 = iMA(Symbol(), 0, FMA_Period, 0, MA_Mode, Applied_price, 2);
   FMA_2 = NormalizeDouble(FMA_2, MarketInfo(Symbol(), MODE_DIGITS));
   SMA_1 = iMA(Symbol(), 0, SMA_Period, 0, MA_Mode, Applied_price, 1);
   SMA_1 = NormalizeDouble(SMA_1, MarketInfo(Symbol(), MODE_DIGITS));
   SMA_2 = iMA(Symbol(), 0, SMA_Period, 0, MA_Mode, Applied_price, 2);
   SMA_2 = NormalizeDouble(SMA_2, MarketInfo(Symbol(), MODE_DIGITS));
   
   //MACDの値の計算
   MacdCurrent = iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_MAIN,0);
   MacdCurrent = NormalizeDouble(MacdCurrent, MarketInfo(Symbol(), MODE_DIGITS));
   MacdPrevious = iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_MAIN,1);
   MacdPrevious = NormalizeDouble(MacdPrevious, MarketInfo(Symbol(), MODE_DIGITS));
   SignalCurrent = iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_SIGNAL,0);
   SignalCurrent = NormalizeDouble(SignalCurrent, MarketInfo(Symbol(), MODE_DIGITS));
   SignalPrevious = iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_SIGNAL,1);
   SignalPrevious = NormalizeDouble(SignalPrevious, MarketInfo(Symbol(), MODE_DIGITS));
   
   //MACDのゴールデンクロス
   //(=1分前のMACD線が1分前のシグナル線よりも下 && 現在のMACD線が現在のシグナル線よりも上)
   if(MacdPrevious <= SignalPrevious && MacdCurrent > SignalCurrent)
   {
      Alert(Symbol(), " : ", "HIGH", " ","MACD Golden Cross");
   }
   
   //MACDのデッドクロス
      
   //クローズ処理
   //ロングポジションクローズ
   //2分前の短期MAが長期MAよりも上で、1分前の短期MAが長期MAよりも下(=デッドクロス)
   if(FMA_2 >= SMA_2 && FMA_1 < SMA_1)
   {
      Alert(Symbol(), " : ", "LOW", " ","MA Death Cross");
   }
   //ショートポジションクローズ
   //2分前の短期MAが長期MAよりも下で、1分前の短期MAが長期MAよりも上(=ゴールデンクロス)
   else if(FMA_2 <= SMA_2 && FMA_1 > SMA_1)
   {
      Alert(Symbol(), " : ", "HIGH", " ","MA Golden Cross");
   }
   
   //今後の課題
   //子供じみているが、7回連続で上(下)がり続けたら1回だけアラートを出したい。(出来ればレアケースとして音も変えたい)
   //MACDも8回連続同方向であれば1回だけアラート(逆張り推奨(HIGHかLOW明記))。あとは裁量かな。
   //MA(100)が上昇トレンドを示している場合に、MACDがゴールデンクロスしたらアラート、逆の場合はどうする？
   //MACDは0より上のゴールデンクロスは通知しない？ただしperfect orderの場合は通知？
   //MACDが0より上のデッドクロス、0より下のゴールデンクロスを通知
   //いかなるクロスでもperfect order形成時は通知する。(「 & PERFECT ORDER!」みたいな感じ。)
   
   return;
   
  }
//+------------------------------------------------------------------+
