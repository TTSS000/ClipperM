//+------------------------------------------------------------------+
//|                                                    Clipper M.mq4 |
//|                                 Copyright 2022, Tislin (ttss000) |
//|                                      https://twitter.com/ttss000 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Tislin (ttss000)"
#property link      "https://twitter.com/ttss000"
#property version   "1.00"
#property strict

// Clipper M : USDJPY H1
// London Open Buy condition : MA_L < MA_M < MA_S < Candle 
// London Open Sell condition : Candle < MA_S < MA_M < MA_L
// Close at London fixing 

// 1 jikan ashi
input int jisa = 7;
input int asiantime_end_JST_winter = 17;
input int london_fix_time_JST_winter = 1;
input double sonkiri_atr_bairitsu = 5;
input int sonkiri_atr_num_bars = 14;
input double in_Slip = 0.5;
input int in_MagicA = 27877062;

int g_D1_prev = 0;
int g_D_server_prev = 0;
string EAComment = "Clipper_M";
// to create magic num, unix time wo motomete 60 de waru, 1fun mai no unix time ni naru
// https://tool.konisimple.net/date/unixtime

datetime g_entryflag_L = 0;
datetime g_entryflag_S = 0;
int g_box_count = 0;
struct MqlTradeRequest {
  int action;
  string symbol;
  double volume;
  double price;
  int deviation;
  double sl;
  double tp;
  int magic;
  int type;
  int position;
  int order;
  string comment;
};



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
//--- create timer
  EventSetTimer(60);

//---
  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//--- destroy timer
  EventKillTimer();

}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//---
  static bool b_IsCheckedToday = false;
  static double d_ma_short = 0;
  static double d_ma_middle = 0;
  static double d_ma_long = 0;
  static datetime dt_start = 0;
  static datetime dt_end = 0;
  static datetime dt_end_one_back = 0;
  int i_start_barshift = 0;
  int i_end_barshift = 0;

  int hizuke_chousei = 0;

  static datetime dt_M1_prev = 0;
  datetime dt_M1_now = iTime(NULL, PERIOD_CURRENT, 0);
  int i_spread_pt = (int)((Ask - Bid) / Point());
  static double d_ATR = 0;
  int local_SummerflagS0W1 = SummerflagS0W1(0);

  if(dt_M1_prev == dt_M1_now) {
    return;
  }
  dt_M1_prev = dt_M1_now;

  int CanH_MT4 = (int) TimeHour(dt_M1_now);
  int CanH = (int) TimeHour(dt_M1_now) + local_SummerflagS0W1 + jisa - 1; // JST
  int CanM = (int) TimeMinute(dt_M1_now);
  //d_ATR25 = iATR(NULL, PERIOD_D1, 25, 1);

  if(24 <= CanH) {
    hizuke_chousei = CanH - 24;
    CanH = hizuke_chousei;
    hizuke_chousei = 1;
  }
  int D1 = TimeDay(dt_M1_now) + hizuke_chousei;  //JST
  int D_server = TimeDay(dt_M1_now);  //JST

  if(g_D_server_prev != D_server) {
    d_ATR = iATR(NULL, PERIOD_H1, sonkiri_atr_num_bars, 1);
    d_ma_short = iMA(NULL, PERIOD_H1, 6, 0, MODE_SMA, PRICE_CLOSE, 1);
    d_ma_middle = iMA(NULL, PERIOD_H1, 24, 0, MODE_SMA, PRICE_CLOSE, 1);
    d_ma_long = iMA(NULL, PERIOD_H1, 120, 0, MODE_SMA, PRICE_CLOSE, 1);

    g_entryflag_L = 0;
    g_entryflag_S = 0;
    //dt_start = 0;
    //ChekPositionAndSetFlag(); // order ga nokotte tara atarashiku ha hairanai
    g_D_server_prev = D_server;
    dt_start = 0;
    dt_end = 0;
    b_IsCheckedToday=false;
  }

  //if(8==TimeMonth(dt_M1_now) && 13==TimeDay(dt_M1_now)){
  //  Print("iTime="+iTime(NULL, PERIOD_CURRENT, 0));
  //}
  int CanH_start = 0;
  int hizuke_chousei_start = 0;

  int hour_temp = 0;
  int server_hour_temp = 0;

  // summer JST 7:00-15:59
  // winter JST 8:00-16:59
  if(dt_start == 0) {
    //if(CanH_MT4 == 1 && CanM == 0) {
    hour_temp = asiantime_end_JST_winter + local_SummerflagS0W1 - 1;  // JST
    while(hour_temp < 0) {
      hour_temp += 24;
    }
    while(24 < hour_temp) {
      hour_temp -= 24;
    }

    server_hour_temp = asiantime_end_JST_winter - (jisa + local_SummerflagS0W1 - 1);
    while(server_hour_temp < 0) {
      server_hour_temp += 24;
    }
    while(24 < server_hour_temp) {
      server_hour_temp -= 24;
    }

    //Print("hour_temp=",hour_temp," CanH=",CanH, " CanM=",CanM," D1=",D1);

    //if(server_hour_temp * 60 <= TimeHour(dt_M1_now) * 60 + TimeMinute(dt_M1_now)) { // server time
    if(hour_temp * 60 <= CanH * 60 + CanM
     //&& !b_IsCheckedToday
     ) { // JST
      dt_start = dt_M1_now; // server time
      b_IsCheckedToday=true;
      //Print("dt_start 0 =" + dt_start);
      if(
        g_entryflag_L == 0
        //&& d_ma_short < iClose(NULL, PERIOD_H1, 1)
        && d_ma_long < iClose(NULL, PERIOD_H1, 1)
        //&& d_ma_middle < d_ma_short
        && d_ma_long < d_ma_middle
        && iRSI(NULL, PERIOD_M5, 14, PRICE_CLOSE, 0) < 30
      ) {
        // long condition
        g_entryflag_L = iTime(NULL, PERIOD_CURRENT, 0);
        BuyOrder(EAComment, in_MagicA, d_ATR);
        //BuyOrder2(EAComment, in_MagicA, range_high, range_low);
        Print("buy flag");

      } else if(
        g_entryflag_S == 0
        //&& d_ma_short > iClose(NULL, PERIOD_H1, 0)
        && iClose(NULL, PERIOD_H1, 0) < d_ma_long
        //&& d_ma_middle > d_ma_short
        && d_ma_long > d_ma_middle
        && 70 < iRSI(NULL, PERIOD_M5, 14, PRICE_CLOSE, 0)

      ) {
        g_entryflag_S = iTime(NULL, PERIOD_CURRENT, 0);
        SellOrder(EAComment, in_MagicA, d_ATR);
        //BuyOrder2(EAComment, in_MagicA, range_high, range_low);
        Print("sell flag");
      }
    }
  }


  if(0 < dt_start && dt_end == 0) {
    // summer JST 7:00-15:59
    // winter JST 8:00-16:59
    CanH_start = (int) TimeHour(dt_start) + local_SummerflagS0W1 + jisa - 1; // jst
    hizuke_chousei_start = 0;
    if(24 <= CanH_start) {
      hizuke_chousei_start = CanH_start - 24;
      CanH_start = hizuke_chousei_start;
      hizuke_chousei_start = 1;
    }
    int D1_start = (int) TimeDay(dt_start) + hizuke_chousei_start; // jst

    hour_temp = london_fix_time_JST_winter  + local_SummerflagS0W1 - 1;  // jst
    while(hour_temp < 0) {
      hour_temp += 24;
    }
    while(24 < hour_temp) {
      hour_temp -= 24;
    }

    server_hour_temp = london_fix_time_JST_winter - (jisa + local_SummerflagS0W1 - 1);
    while(server_hour_temp < 0) {
      server_hour_temp += 24;
    }
    while(24 < server_hour_temp) {
      server_hour_temp -= 24;
    }
    //Print("CanH_start=",CanH_start,",hour_temp=",hour_temp," CanH=",CanH, " CanM=",CanM," D1=",D1," D1_start=",D1_start );

    //if(server_hour_temp * 60 <= TimeHour(dt_M1_now) * 60 + TimeMinute(dt_M1_now)) { // server time
    if(hour_temp * 60 <= CanH * 60 + CanM
        && D1_start != D1
      ) {

      Close_Symbol(in_MagicA);
      dt_end = iTime(NULL, PERIOD_CURRENT, 0);
    }

    //if(hour_temp * 60 <= CanH * 60 + CanM
    //    && D1_start != D1
    //  ) {
    //  //if(CanH == 16 && CanM == 0) {
    //  Close_Symbol(in_MagicA);
    //  dt_end = iTime(NULL, PERIOD_CURRENT, 0);
    //}
  }



}
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
//---

}
//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
{
//---
  double ret = 0.0;
//---

//---
  return(ret);
}
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
//---

}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void BuyOrder(string comment, int local_magic_BO, double local_ATR)
{
  double local_SL = 0, local_TP = 0;
  int index_ABCD = 0;

  local_TP = 0;
  local_SL = NormalizeDouble(Ask - local_ATR * sonkiri_atr_bairitsu, Digits());

  int ticket = OrderSend(NULL, OP_BUY, 0.1, Ask, int(in_Slip * 10),
                         local_SL, local_TP, comment, local_magic_BO, 0, clrRed);
  if(ticket < 0) {
    Print("OrderSend failed with error #", GetLastError(),
          " ASK=" + DoubleToString(Ask, Digits()) +
          " SL=" + DoubleToString(local_SL,Digits) + " TP=" + DoubleToString(local_TP, Digits()));
    g_entryflag_L = 0;
  } else {
    //PlaySound("ok.wav");
    Print(EAComment + "_" + comment);
  }
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void SellOrder(string comment, int local_magic_SO, double local_ATR)
{
  double local_SL = 0, local_TP = 0;
  int index_ABCD = 0;

  local_TP = 0;
  local_SL = NormalizeDouble(Bid + local_ATR * sonkiri_atr_bairitsu, Digits());;

  int ticket = OrderSend(NULL, OP_SELL, 0.1, Bid, int(in_Slip * 10),
                         local_SL, local_TP, comment, local_magic_SO, 0, clrRed);
  if(ticket < 0) {
    Print("OrderSend failed with error #", GetLastError(),
          " BID=" + DoubleToString(Bid, Digits()) +
          " SL=" + DoubleToString(local_SL,Digits) + " TP=" + DoubleToString(local_TP, Digits()));
    g_entryflag_S = 0;
  } else {
    //PlaySound("ok.wav");
    Print(EAComment + "_" + comment);
  }
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void Close_Symbol(int local_magic)
{
  for(int i = OrdersTotal() - 1 ; 0 <= i ; i--) {
    int res = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
    //int res = OrderSelect(i, SELECT_BY_POS);
    if(OrderMagicNumber() != local_magic) {
      //Print("OC OrderMagicNumber, local_magic =" + IntegerToString(OrderMagicNumber()) + "  " + IntegerToString(local_magic));
      continue;
    }
    if(OrderSymbol() != Symbol()) {
      Print("OrderSymbol Symbol=" + OrderSymbol() + "  " + Symbol());
      continue;
    }
    //if(OrderComment() != EAComment + "_" + comment) {
    //  Print("order comment, comment =" + OrderComment() + "    " + comment);
    //  continue;
    //}
    if(OrderType() == OP_BUY || OrderType() == OP_SELL) {
      bool b_res = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), int(in_Slip * 10), clrNONE);
      if(!res) {
        PrintFormat("OrderClose error %d",GetLastError()," ticket=" + IntegerToString(OrderTicket())); // if unable to send the request, output the error code
      }

    } else {
      if(!OrderDelete(OrderTicket(), clrNONE)) {
        PrintFormat("OrderDelete error %d",GetLastError()," ticket=" + IntegerToString(OrderTicket())); // if unable to send the request, output the error code
      }
    }
  }
}
//+------------------------------------------------------------------+
// >>---------<< サマータイム関数 >>--------------------------------------------------------------------<<
// copy right takulogu san
// http://fxbo.takulogu.com/mql4/backtest/summertime/
int SummerflagS0W1(int shift)   // TimeFlag と summer はグローバル関数
{
  static int summer = 0;
  static int TimeFlag = 0;
  int B = 0;
  int CanM = (int)TimeMonth(iTime(NULL,0,shift)); //月取得
  int CanD = (int)TimeDay(iTime(NULL,0,shift)); //日取得
  int CanW = (int)TimeDayOfWeek(iTime(NULL,0,shift));//曜日取得
  if(TimeFlag != CanD) { //>>日が変わった際に計算
    if(CanM >= 3 && CanM <= 11) { //------------------------------------------- 3月から11月範囲計算開始
      if(CanM == 3) { //------------------------------------------- 3月の計算（月曜日が○日だったら夏時間）
        if(CanD <= 8) {
          summer = false;
        }
        if(CanD == 9) {
          if(CanW == 1) {
            summer = true; // 9日の月曜日が第3月曜日の最小日（第2日曜の最小が8日の為）
          } else {
            summer = false;
          }
        }
        if(CanD == 10) {
          if(CanW <= 2) {
            summer = true; // 10日が火曜以下であれば,第3月曜日を迎えた週
          } else {
            summer = false;
          }
        }
        if(CanD == 11) {
          if(CanW <= 3) {
            summer = true; // 11日が水曜以下であれば,第3月曜日を迎えた週
          } else {
            summer = false;
          }
        }
        if(CanD == 12) {
          if(CanW <= 4) {
            summer = true; // 12日が木曜以下であれば,第3月曜日を迎えた週
          } else {
            summer = false;
          }
        }
        if(CanD >= 13) {
          summer = true;  // 13日以降は上の条件のいずれかが必ず満たされる
        }
      }
      if(CanM == 11) { //------------------------------------------ 11月の計算（月曜日が○日だったら冬時間）
        if(CanD == 1) {
          summer = true;
        }
        if(CanD == 2) {
          if(CanW == 1) {
            summer = false; // 2日の月曜日が第2月曜日の最小日（第1日曜の最小が1日の為）
          } else {
            summer = true;
          }
        }
        if(CanD == 3) {
          if(CanW <= 2) {
            summer = false; // 3日が火曜以下であれば,第2月曜日を迎えた週
          } else {
            summer = true;
          }
        }
        if(CanD == 4) {
          if(CanW <= 3) {
            summer = false; // 4日が水曜以下であれば,第2月曜日を迎えた週
          } else {
            summer = true;
          }
        }
        if(CanD == 5) {
          if(CanW <= 4) {
            summer = false; // 5日が木曜以下であれば,第2月曜日を迎えた週
          } else {
            summer = true;
          }
        }
        if(CanD == 6) {
          if(CanW <= 5) {
            summer = false; // 6日が金曜以下であれば,第2月曜日を迎えた週
          } else {
            summer = true;
          }
        }
        if(CanD >= 7) {
          summer = false;  // 7日以降が何曜日に来ても第2月曜日を迎えている(7日が日なら迎えていないが8日で迎える)
        }
      }
      if(CanM != 3 && CanM != 11)
        summer = true; //　4月~10月は無条件で夏時間
    } //--------------------------------------------------------------- 3月から11月範囲計算終了
    else {
      summer = false; //12月~2月は無条件で冬時間
    }
    TimeFlag = CanD;
  }
  if(summer == true) {
    B = 0;
  } else {
    B = 1;
  }
  return(B);
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void Delete_Symbol(int local_magic)
{
  MqlTradeRequest request;
  ZeroMemory(request);

  for(int i = OrdersTotal() - 1 ; 0 <= i ; i--) {
    if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != local_magic) {
        continue;
      }
      if(OrderType() == OP_BUY || OrderType() == OP_SELL) {
        continue;

      }

      request.order = OrderTicket(); // ticket of the position
      request.symbol = _Symbol;   // symbol
      request.volume = OrderLots();
      request.magic = local_magic;       // MagicNumber of the position
      if(!OrderDelete(request.order, clrNONE)) {
        PrintFormat("OrderDelete error %d",GetLastError()," ticket=" + IntegerToString(request.order)); // if unable to send the request, output the error code
      }
    }
  }
}
//+------------------------------------------------------------------+
