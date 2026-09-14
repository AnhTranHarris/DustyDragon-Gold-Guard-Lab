#property strict
#property version   "1.00"
#property description "Dusty Dragon Gold Regime Guard M002"
#property description "Research guard: detects Hunter collapse, spread stress, reopen risk and whipsaw."
#property description "Advisory only: never sends, closes, deletes or modifies trades."

input string InpSymbolContains = "XAUUSD";
input long   InpHunterMagic = 5555;
input int    InpTimerSeconds = 1;
input int    InpCalendarRefreshSeconds = 30;
input int    InpNewsLookaheadMinutes = 120;
input int    InpFastWindowTrades = 10;
input int    InpConfirmWindowTrades = 20;
input double InpFastRedProfitFactor = 0.45;
input double InpFastRedWinRate = 0.30;
input double InpConfirmRedProfitFactor = 0.80;
input double InpConfirmRedWinRate = 0.40;
input int    InpRedLossStreak = 6;
input int    InpAmberLossStreak = 4;
input double InpSpreadRatioAmber = 1.50;
input double InpSpreadRatioRed = 2.00;
input double InpWhipsawRedEfficiency = 0.15;
input double InpWhipsawAmberEfficiency = 0.30;
input int    InpReopenWarmupMinutes = 90;
input int    InpPriceWindowSeconds = 60;
input string InpOutputFile = "DustyDragon\\GoldGuard\\regime_guard.csv";

int g_file = INVALID_HANDLE;
ulong g_pending_deals[];
datetime g_last_news_refresh = 0;
int g_cached_news_minutes = 2147483647;
string g_cached_event_name = "";

double g_trade_pnl[];
int g_trade_count = 0;
int g_loss_streak = 0;

double g_mid_prices[];
datetime g_mid_times[];

double g_spread_ewma = 0.0;
int g_spread_samples = 0;
datetime g_reopen_detected = 0;
datetime g_last_tick_time = 0;
string g_state = "AMBER";
string g_reason = "startup-warmup";

bool IsHunterSymbol(const string symbol)
  {
   return(StringFind(symbol,InpSymbolContains)>=0);
  }

bool SelectHunterDeal(const ulong ticket)
  {
   if(ticket==0 || !HistoryDealSelect(ticket))
      return(false);
   return(HistoryDealGetInteger(ticket,DEAL_MAGIC)==InpHunterMagic &&
          IsHunterSymbol(HistoryDealGetString(ticket,DEAL_SYMBOL)));
  }

void EnqueueDeal(const ulong ticket)
  {
   int n=ArraySize(g_pending_deals);
   if(ArrayResize(g_pending_deals,n+1,64)==n+1)
      g_pending_deals[n]=ticket;
   else
      PrintFormat("GoldRegimeGuard queue resize failed for deal %I64u, error=%d",ticket,GetLastError());
  }

bool IsExitDeal(const ulong ticket)
  {
   long entry=HistoryDealGetInteger(ticket,DEAL_ENTRY);
   return(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY || entry==DEAL_ENTRY_INOUT);
  }

double DealNetPnl(const ulong ticket)
  {
   return(HistoryDealGetDouble(ticket,DEAL_PROFIT)+
          HistoryDealGetDouble(ticket,DEAL_COMMISSION)+
          HistoryDealGetDouble(ticket,DEAL_SWAP)+
          HistoryDealGetDouble(ticket,DEAL_FEE));
  }

void PushTradePnl(const double pnl)
  {
   int maxn=MathMax(30,MathMax(InpFastWindowTrades,InpConfirmWindowTrades));
   int n=ArraySize(g_trade_pnl);
   if(n<maxn)
     {
      ArrayResize(g_trade_pnl,n+1,maxn);
      g_trade_pnl[n]=pnl;
     }
   else
     {
      for(int i=1;i<n;i++)
         g_trade_pnl[i-1]=g_trade_pnl[i];
      g_trade_pnl[n-1]=pnl;
     }
   g_trade_count++;
   if(pnl<0.0)
      g_loss_streak++;
   else if(pnl>0.0)
      g_loss_streak=0;
  }

void WindowMetrics(const int requested,double &pf,double &win_rate,double &net,int &count)
  {
   int n=ArraySize(g_trade_pnl);
   count=MathMin(requested,n);
   double gross_profit=0.0;
   double gross_loss=0.0;
   int wins=0;
   net=0.0;
   if(count<=0)
     {
      pf=0.0;
      win_rate=0.0;
      return;
     }
   int start=n-count;
   for(int i=start;i<n;i++)
     {
      double p=g_trade_pnl[i];
      net+=p;
      if(p>0.0)
        {
         gross_profit+=p;
         wins++;
        }
      else if(p<0.0)
         gross_loss-=p;
     }
   pf=(gross_loss>0.0 ? gross_profit/gross_loss : (gross_profit>0.0 ? 999.0 : 0.0));
   win_rate=(double)wins/(double)count;
  }

double CurrentSpreadPoints()
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
      return(-1.0);
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(point<=0.0)
      return(-1.0);
   return((tick.ask-tick.bid)/point);
  }

void UpdateSpreadBaseline(const double spread)
  {
   if(spread<0.0)
      return;
   if(g_spread_samples==0)
      g_spread_ewma=spread;
   else
     {
      double alpha=(g_spread_samples<120 ? 0.05 : 0.01);
      g_spread_ewma=(alpha*spread)+((1.0-alpha)*g_spread_ewma);
     }
   g_spread_samples++;
  }

void UpdatePriceWindow()
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
      return;
   datetime tick_time=(datetime)tick.time;
   if(tick_time<=0)
      return;

   datetime now=TimeTradeServer();
   if(g_last_tick_time>0 && tick_time>g_last_tick_time && (tick_time-g_last_tick_time)>=300)
      g_reopen_detected=now;
   g_last_tick_time=tick_time;

   double mid=(tick.bid+tick.ask)*0.5;
   int n=ArraySize(g_mid_prices);
   ArrayResize(g_mid_prices,n+1,128);
   ArrayResize(g_mid_times,n+1,128);
   g_mid_prices[n]=mid;
   g_mid_times[n]=now;

   datetime cutoff=now-MathMax(10,InpPriceWindowSeconds);
   int keep_from=0;
   while(keep_from<ArraySize(g_mid_times) && g_mid_times[keep_from]<cutoff)
      keep_from++;
   if(keep_from>0)
     {
      int oldn=ArraySize(g_mid_prices);
      int newn=oldn-keep_from;
      for(int i=0;i<newn;i++)
        {
         g_mid_prices[i]=g_mid_prices[i+keep_from];
         g_mid_times[i]=g_mid_times[i+keep_from];
        }
      ArrayResize(g_mid_prices,newn);
      ArrayResize(g_mid_times,newn);
     }
  }

double DirectionalEfficiency()
  {
   int n=ArraySize(g_mid_prices);
   if(n<10)
      return(-1.0);
   double path=0.0;
   for(int i=1;i<n;i++)
      path+=MathAbs(g_mid_prices[i]-g_mid_prices[i-1]);
   if(path<=0.0)
      return(0.0);
   return(MathAbs(g_mid_prices[n-1]-g_mid_prices[0])/path);
  }

void RefreshNewsCache(const datetime now_trade_server)
  {
   g_cached_news_minutes=2147483647;
   g_cached_event_name="";
   if(MQLInfoInteger(MQL_TESTER))
     {
      g_cached_event_name="TESTER_CACHE_REQUIRED";
      return;
     }
   MqlCalendarValue values[];
   datetime to=now_trade_server+(InpNewsLookaheadMinutes*60);
   ResetLastError();
   int n=CalendarValueHistory(values,now_trade_server,to,NULL,"USD");
   if(n<0)
     {
      PrintFormat("GoldRegimeGuard CalendarValueHistory failed, error=%d",GetLastError());
      return;
     }
   for(int i=0;i<n;i++)
     {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id,ev))
         continue;
      if(ev.importance!=CALENDAR_IMPORTANCE_HIGH)
         continue;
      int mins=(int)((values[i].time-now_trade_server)/60);
      if(mins>=0 && mins<g_cached_news_minutes)
        {
         g_cached_news_minutes=mins;
         g_cached_event_name=ev.name;
        }
     }
  }

void EvaluateState()
  {
   double fast_pf,fast_wr,fast_net;
   double confirm_pf,confirm_wr,confirm_net;
   int fast_n,confirm_n;
   WindowMetrics(InpFastWindowTrades,fast_pf,fast_wr,fast_net,fast_n);
   WindowMetrics(InpConfirmWindowTrades,confirm_pf,confirm_wr,confirm_net,confirm_n);

   double spread=CurrentSpreadPoints();
   double spread_ratio=(g_spread_ewma>0.0 && spread>=0.0 ? spread/g_spread_ewma : 1.0);
   double efficiency=DirectionalEfficiency();
   datetime now=TimeTradeServer();

   g_state="GREEN";
   g_reason="healthy";

   if(g_reopen_detected>0 && (now-g_reopen_detected)<(InpReopenWarmupMinutes*60))
     {
      g_state="RED";
      g_reason="reopen-warmup";
      return;
     }

   if(spread_ratio>=InpSpreadRatioRed && g_spread_samples>=20)
     {
      g_state="RED";
      g_reason="spread-stress";
      return;
     }

   if(g_loss_streak>=InpRedLossStreak)
     {
      g_state="RED";
      g_reason="loss-streak";
      return;
     }

   if(fast_n>=InpFastWindowTrades && fast_net<0.0 &&
      fast_pf<=InpFastRedProfitFactor && fast_wr<=InpFastRedWinRate)
     {
      g_state="RED";
      g_reason="fast-expectancy-collapse";
      return;
     }

   if(confirm_n>=InpConfirmWindowTrades && confirm_net<0.0 &&
      (confirm_pf<InpConfirmRedProfitFactor || confirm_wr<InpConfirmRedWinRate))
     {
      g_state="RED";
      g_reason="confirmed-negative-expectancy";
      return;
     }

   if(efficiency>=0.0 && efficiency<InpWhipsawRedEfficiency)
     {
      g_state="RED";
      g_reason="whipsaw";
      return;
     }

   if((spread_ratio>=InpSpreadRatioAmber && g_spread_samples>=20) ||
      g_loss_streak>=InpAmberLossStreak ||
      (efficiency>=0.0 && efficiency<InpWhipsawAmberEfficiency))
     {
      g_state="AMBER";
      g_reason="degraded-market-quality";
     }
  }

void WriteRow(const string tag,const ulong deal_ticket=0,const double deal_pnl=0.0)
  {
   if(g_file==INVALID_HANDLE)
      return;
   double fast_pf,fast_wr,fast_net;
   double confirm_pf,confirm_wr,confirm_net;
   int fast_n,confirm_n;
   WindowMetrics(InpFastWindowTrades,fast_pf,fast_wr,fast_net,fast_n);
   WindowMetrics(InpConfirmWindowTrades,confirm_pf,confirm_wr,confirm_net,confirm_n);
   double spread=CurrentSpreadPoints();
   double spread_ratio=(g_spread_ewma>0.0 && spread>=0.0 ? spread/g_spread_ewma : 1.0);
   double efficiency=DirectionalEfficiency();

   FileSeek(g_file,0,SEEK_END);
   FileWrite(g_file,
             TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
             TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),
             tag,_Symbol,g_state,g_reason,
             DoubleToString(spread,1),DoubleToString(g_spread_ewma,1),DoubleToString(spread_ratio,3),
             DoubleToString(efficiency,3),
             fast_n,DoubleToString(fast_pf,3),DoubleToString(fast_wr,3),DoubleToString(fast_net,2),
             confirm_n,DoubleToString(confirm_pf,3),DoubleToString(confirm_wr,3),DoubleToString(confirm_net,2),
             g_loss_streak,g_cached_news_minutes,g_cached_event_name,
             deal_ticket,DoubleToString(deal_pnl,2));
  }

void DrainPendingDeals()
  {
   int n=ArraySize(g_pending_deals);
   for(int i=0;i<n;i++)
     {
      ulong ticket=g_pending_deals[i];
      if(!SelectHunterDeal(ticket))
         continue;
      double pnl=0.0;
      if(IsExitDeal(ticket))
        {
         pnl=DealNetPnl(ticket);
         PushTradePnl(pnl);
        }
      EvaluateState();
      WriteRow("hunter_deal",ticket,pnl);
     }
   if(n>0)
      ArrayResize(g_pending_deals,0);
  }

int OnInit()
  {
   g_file=FileOpen(InpOutputFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_COMMON,',');
   if(g_file==INVALID_HANDLE)
     {
      PrintFormat("GoldRegimeGuard FileOpen failed, error=%d",GetLastError());
      return(INIT_FAILED);
     }
   if(FileSize(g_file)==0)
      FileWrite(g_file,"quote_server_time","trade_server_time","tag","symbol","state","reason","spread_points","spread_ewma","spread_ratio","directional_efficiency","fast_n","fast_pf","fast_win_rate","fast_net","confirm_n","confirm_pf","confirm_win_rate","confirm_net","loss_streak","high_impact_usd_minutes","event_name","deal_ticket","deal_net_pnl");

   if(!EventSetTimer(MathMax(1,InpTimerSeconds)))
     {
      PrintFormat("GoldRegimeGuard EventSetTimer failed, error=%d",GetLastError());
      FileClose(g_file);
      g_file=INVALID_HANDLE;
      return(INIT_FAILED);
     }

   datetime now=TimeTradeServer();
   RefreshNewsCache(now);
   g_last_news_refresh=now;
   EvaluateState();
   WriteRow("init");
   FileFlush(g_file);
   Print("GoldRegimeGuard M002 started in advisory-only mode");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   DrainPendingDeals();
   EvaluateState();
   WriteRow("deinit");
   if(g_file!=INVALID_HANDLE)
     {
      FileFlush(g_file);
      FileClose(g_file);
      g_file=INVALID_HANDLE;
     }
  }

void OnTimer()
  {
   datetime now=TimeTradeServer();
   UpdatePriceWindow();
   double spread=CurrentSpreadPoints();
   UpdateSpreadBaseline(spread);
   if(g_last_news_refresh==0 || (now-g_last_news_refresh)>=MathMax(1,InpCalendarRefreshSeconds))
     {
      RefreshNewsCache(now);
      g_last_news_refresh=now;
     }
   DrainPendingDeals();
   EvaluateState();
   WriteRow("timer");
   FileFlush(g_file);
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD && trans.deal!=0)
      EnqueueDeal(trans.deal);
  }
