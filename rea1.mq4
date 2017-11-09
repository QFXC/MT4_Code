//+------------------------------------------------------------------+
//|                                            Relativity_EA_V01.mq4 |
//|                                                 Quant FX Capital |
//|                                   https://www.quantfxcapital.com |
//+------------------------------------------------------------------+
#property copyright "Quant FX Capital"
#property link      "https://www.quantfxcapital.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum ENUM_TRADE_SIGNAL
  {
   TRADE_SIGNAL_VOID=-1,
   TRADE_SIGNAL_NEUTRAL,
   TRADE_SIGNAL_BUY,
   TRADE_SIGNAL_SELL
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum ENUM_ORDER_SET
  {
   ORDER_SET_ALL=-1,
   ORDER_SET_BUY,
   ORDER_SET_SELL,
   ORDER_SET_BUY_LIMIT,
   ORDER_SET_SELL_LIMIT,
   ORDER_SET_BUY_STOP,
   ORDER_SET_SELL_STOP,
   ORDER_SET_LONG,
   ORDER_SET_SHORT,
   ORDER_SET_LIMIT,
   ORDER_SET_STOP,
   ORDER_SET_MARKET,
   ORDER_SET_PENDING
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum MM
  {
   MM_FIXED_LOT,
   MM_RISK_PERCENT,
   MM_FIXED_RATIO,
   MM_FIXED_RISK,
   MM_FIXED_RISK_PER_POINT,
  };




//ontick()
	input int timeframe=0;
	input int virtual_sl=0;
	input int virtual_tp=0;
	input int breakeven_threshold=500;
	input int breakeven_plus=0;
	
	//trailing stop variables
		input int trail_value=20;
		input int trail_threshold=500;
		input int trail_step=20;
	
	
	input bool exit_opposite_signal=false;
	input int maxtrades=1;
	input bool entry_new_bar=true;
	input bool wait_next_bar_on_load=true;
	input int start_time_hour=22;
	input int start_time_minute=0;
	input int end_time_hour=22;
	input int end_time_minute=0;
	input int gmt=0;


//enter_order
	input int takeprofit=0;
	input int entering_max_slippage=5; // the default used to be 50
	input string order_comment="Relativity EA"; // allows the robot to enter a description for the order. An empty string is a default value.
	input int order_magic=12345; // An EA can only have one magic number. Used to identify the EA that is managing the order.
	input int order_expire=0; // The default is 0. The expiration is only needed when opening pending orders. I thought this was supposed to be the datetime type??? An exact date is needed to close the order.
	input bool market_exec=false;
	input bool long_allowed=true;
	input bool short_allowed=true;
	input color arrow_color_short=clrRed;
	
	input int exiting_max_slippage=50; // i added this

//????
	input color arrow_color_long=clrGreen;


//calculate_lots
	input string symbol=NULL;
	input double lotsize=0.1;
	input int stoploss=0;
	input MM money_management=MM_FIXED_LOT;
	input double mm1_risk=0.05;
	input double mm2_lots=0.1;
	input double mm2_per=1000;
	input double mm3_risk=50;
	input double mm4_risk=50;



//signal_zigzag
	input int depth=12;
	input int deviation=5;
	input int backstep=3;
	input int shift=1;

int signal_zigzag()
{
   int signal=TRADE_SIGNAL_NEUTRAL;
   double zigzag=iCustom(NULL,0,"ZigZag",depth,deviation,backstep,0,shift);
   double open=iOpen(NULL,0,shift);
   
   if (zigzag>0 && zigzag<EMPTY_VALUE)
   {
      if (zigzag>open)
         signal=TRADE_SIGNAL_SELL;
      else if (zigzag<open)
         signal=TRADE_SIGNAL_BUY;
   }
   
   return signal;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int signal_entry()
  {
   int signal=TRADE_SIGNAL_NEUTRAL;
//add entry signals below
   signal=signal_add(signal,signal_zigzag());
//return entry signal
   return signal;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int signal_exit()
  {
   int signal=TRADE_SIGNAL_NEUTRAL;
//add entry signals below

//return exit signal
   return signal;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

double calculate_lots()
  {
   double lots=mm(money_management,symbol,lotsize,stoploss,mm1_risk,mm2_lots,mm2_per,mm3_risk,mm4_risk);
   return lots;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void enter_order(ENUM_ORDER_TYPE type)
  {
   if(type==OP_BUY || type==OP_BUYSTOP || type==OP_BUYLIMIT)
      if(!long_allowed) return;
   if(type==OP_SELL || type==OP_SELLSTOP || type==OP_SELLLIMIT)
      if(!short_allowed) return;
   double lots=calculate_lots();
   entry(NULL,type,lots,0,stoploss,takeprofit,order_comment,order_magic,order_expire,arrow_color_short,market_exec); // why does it only use the arrow_color_short variable and arrow_color_long is never used?
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void close_all()
  {
   exit_all_set(ORDER_SET_ALL,order_magic);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void close_all_long()
  {
   exit_all_set(ORDER_SET_BUY,order_magic);
//exit_all_set(ORDER_SET_BUY_STOP,order_magic);
//exit_all_set(ORDER_SET_BUY_LIMIT,order_magic);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void close_all_short()
  {
   exit_all_set(ORDER_SET_SELL,order_magic);
//exit_all_set(ORDER_SET_SELL_STOP,order_magic);
//exit_all_set(ORDER_SET_SELL_LIMIT,order_magic);
  }
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int OnInit()
  {
//---

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
/* time check */
   bool time_in_range=is_time_in_range(TimeCurrent(),start_time_hour,start_time_minute,end_time_hour,end_time_minute,gmt);

/* signals */
   int entry=0,exit=0;
   entry=signal_entry();
   exit=signal_exit();

/* exit */
   if(exit==TRADE_SIGNAL_BUY)
     {
      close_all();
     }
   else if(exit==TRADE_SIGNAL_SELL)
     {
      close_all_long();
     }
   else if(exit==TRADE_SIGNAL_VOID)
     {
      close_all_short();
     }

/* entry */
   int count_orders=0;
   if(entry>0)
     {
      if(entry==TRADE_SIGNAL_BUY)
        {
         if(exit_opposite_signal)
            exit_all_set(ORDER_SET_SELL,order_magic);
         count_orders=count_orders(-1,order_magic);
         if(maxtrades>count_orders)
           {
            if(!entry_new_bar || (entry_new_bar && is_new_bar(symbol,timeframe,wait_next_bar_on_load)))
               enter_order(OP_BUY);
           }
        }
      else if(entry==TRADE_SIGNAL_SELL)
        {
         if(exit_opposite_signal)
            exit_all_set(ORDER_SET_BUY,order_magic);
         count_orders=count_orders(-1,order_magic);
         if(maxtrades>count_orders)
           {
            if(!entry_new_bar || (entry_new_bar && is_new_bar(symbol,timeframe,wait_next_bar_on_load)))
               enter_order(OP_SELL);
           }
        }
     }

/* misc tasks */
//if(breakeven_threshold>0) breakeven_check(breakeven_threshold,breakeven_plus,order_magic);
//if(trail_value>0) trailingstop_check(trail_value,trail_threshold,trail_step,order_magic);
   virtualstop_check(virtual_sl,virtual_tp);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void signal_manage(ENUM_TRADE_SIGNAL &entry,ENUM_TRADE_SIGNAL &exit)
  {
   if(exit==TRADE_SIGNAL_VOID)
      entry=TRADE_SIGNAL_NEUTRAL;
   if(exit==TRADE_SIGNAL_BUY && entry==TRADE_SIGNAL_SELL)
      entry=TRADE_SIGNAL_NEUTRAL;
   if(exit==TRADE_SIGNAL_SELL && entry==TRADE_SIGNAL_BUY)
      entry=TRADE_SIGNAL_NEUTRAL;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

bool breakeven_check_order(int ticket,int threshold,int plus)
  {
   if(ticket<=0) return true;
   if(!OrderSelect(ticket,SELECT_BY_TICKET)) return false;
   int digits=(int)MarketInfo(OrderSymbol(),MODE_DIGITS);
   double point=MarketInfo(OrderSymbol(),MODE_POINT);
   bool result=true;
   if(OrderType()==OP_BUY)
     {
      double newsl=OrderOpenPrice()+plus*point;
      double profit_in_pts=OrderClosePrice()-OrderOpenPrice();
      if(OrderStopLoss()==0 || compare_doubles(newsl,OrderStopLoss(),digits)>0)
         if(compare_doubles(profit_in_pts,threshold*point,digits)>=0)
            result=modify(ticket,newsl);
     }
   else if(OrderType()==OP_SELL)
     {
      double newsl=OrderOpenPrice()-plus*point;
      double profit_in_pts=OrderOpenPrice()-OrderClosePrice();
      if(OrderStopLoss()==0 || compare_doubles(newsl,OrderStopLoss(),digits)<0)
         if(compare_doubles(profit_in_pts,threshold*point,digits)>=0)
            result=modify(ticket,newsl);
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void breakeven_check(int threshold,int plus,int magic=-1)
  {
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS))
         if(magic==-1 || magic==OrderMagicNumber())
            breakeven_check_order(OrderTicket(),threshold,plus);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

bool modify_order(int ticket,double sl,double tp=-1,double entryPrice=-1,datetime expire=0,color a_color=clrNONE)
  {
   bool result=false;
   if(OrderSelect(ticket,SELECT_BY_TICKET))
     {
      string instrument=OrderSymbol();
      int digits=(int)MarketInfo(instrument,MODE_DIGITS);
      if(sl==-1) sl=OrderStopLoss();
      else sl=NormalizeDouble(sl,digits);
      if(tp==-1) tp=OrderTakeProfit();
      else tp=NormalizeDouble(tp,digits);
      if(OrderType()<=1)
        {
         if(compare_doubles(sl,OrderStopLoss(),digits)==0 && 
            compare_doubles(tp,OrderTakeProfit(),digits)==0)
            return true;
         entryPrice=OrderOpenPrice();
        }
      else if(OrderType()>1)
        {
         if(entryPrice==-1)
            entryPrice=OrderOpenPrice();
         else entryPrice=NormalizeDouble(entryPrice,digits);
         if(compare_doubles(entryPrice,OrderOpenPrice(),digits)==0 && 
            compare_doubles(sl,OrderStopLoss(),digits)==0 && 
            compare_doubles(tp,OrderTakeProfit(),digits)==0 && 
            expire==OrderExpiration())
            return true;
        }
      result=OrderModify(ticket,entryPrice,sl,tp,expire,a_color);
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

bool modify(int ticket,double sl,double tp=-1,double entryPrice=-1,datetime expire=0,color a_color=clrNONE,int retries=3,int sleep=500)
  {
   bool result=false;
   if(ticket>0)
     {
      for(int i=0;i<retries;i++)
        {
         if(!IsConnected()) Print("No internet connection");
         else if(!IsExpertEnabled()) Print("Experts not enabled in trading platform");
         else if(IsTradeContextBusy()) Print("Trade context is busy");
         else if(!IsTradeAllowed()) Print("Trade is not allowed in trading platform");
         else result=modify_order(ticket,sl,tp,entryPrice,expire,a_color);
         if(result)
            break;
         Sleep(sleep);
        }
     }
   else Print("Invalid ticket for modify function");
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

int compare_doubles(double var1,double var2,int precision)
  {
   double point=MathPow(10,-precision); //10^(-precision)
   int var1_int=(int) (var1/point);
   int var2_int=(int) (var2/point);
   if(var1_int>var2_int)
      return 1;
   else if(var1_int<var2_int)
      return -1;
   return 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

bool exit_order(int ticket,double size=-1,color a_color=clrNONE)
  {
   bool result=false;
   if(OrderSelect(ticket,SELECT_BY_TICKET))
     {
      if(OrderType()<=1)
        {
         result=OrderClose(ticket,OrderLots(),OrderClosePrice(),exiting_max_slippage,a_color);
        }
      else if(OrderType()>1)
        {
         result=OrderDelete(ticket,a_color);
        }
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

bool exit(int ticket,color a_color=clrNONE,int retries=3,int sleep=500)
  {
   bool result=false;
   for(int i=0;i<retries;i++)
     {
      if(!IsConnected()) Print("No internet connection");
      else if(!IsExpertEnabled()) Print("Experts not enabled in trading platform");
      else if(IsTradeContextBusy()) Print("Trade context is busy");
      else if(!IsTradeAllowed()) Print("Trade is not allowed in trading platform");
      else result=exit_order(ticket,a_color);
      if(result)
         break;
      Print("Closing order# "+DoubleToStr(OrderTicket(),0)+" failed "+DoubleToStr(GetLastError(),0));
      Sleep(sleep);
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void exit_all(int type=-1,int magic=-1)
  {
   for(int i=OrdersTotal();i>=0;i--)
     {
      if(OrderSelect(i,SELECT_BY_POS))
        {
         if((type==-1 || type==OrderType()) && (magic==-1 || magic==OrderMagicNumber()))
            exit(OrderTicket());
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void exit_all_set(ENUM_ORDER_SET type=-1,int magic=-1)
  {
   for(int i=OrdersTotal();i>=0;i--)
     {
      if(OrderSelect(i,SELECT_BY_POS))
        {
         if(magic==-1 || magic==OrderMagicNumber())
           {
            int ordertype=OrderType();
            int ticket=OrderTicket();
            switch(type)
              {
               case ORDER_SET_BUY:
                  if(ordertype==OP_BUY) exit(ticket);
                  break;
               case ORDER_SET_SELL:
                  if(ordertype==OP_SELL) exit(ticket);
                  break;
               case ORDER_SET_BUY_LIMIT:
                  if(ordertype==OP_BUYLIMIT) exit(ticket);
                  break;
               case ORDER_SET_SELL_LIMIT:
                  if(ordertype==OP_SELLLIMIT) exit(ticket);
                  break;
               case ORDER_SET_BUY_STOP:
                  if(ordertype==OP_BUYSTOP) exit(ticket);
                  break;
               case ORDER_SET_SELL_STOP:
                  if(ordertype==OP_SELLSTOP) exit(ticket);
                  break;
               case ORDER_SET_LONG:
                  if(ordertype==OP_BUY || ordertype==OP_BUYLIMIT || ordertype==OP_BUYSTOP)
                  exit(ticket);
                  break;
               case ORDER_SET_SHORT:
                  if(ordertype==OP_SELL || ordertype==OP_SELLLIMIT || ordertype==OP_SELLSTOP)
                  exit(ticket);
                  break;
               case ORDER_SET_LIMIT:
                  if(ordertype==OP_BUYLIMIT || ordertype==OP_SELLLIMIT)
                  exit(ticket);
                  break;
               case ORDER_SET_STOP:
                  if(ordertype==OP_BUYSTOP || ordertype==OP_SELLSTOP)
                  exit(ticket);
                  break;
               case ORDER_SET_MARKET:
                  if(ordertype<=1) exit(ticket);
                  break;
               case ORDER_SET_PENDING:
                  if(ordertype>1) exit(ticket);
                  break;
               default: exit(ticket);
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// the distanceFromCurrentPrice parameter is to specify what type of order you would like to enter
int send_order(string instrument,int cmd,double lots,int distanceFromCurrentPrice,int sl,int tp,string comment=NULL,int magic=0,int expire=0,color a_clr=clrNONE,bool market=false)
  {
   double entryPrice=0; 
   double price_sl=0; 
   double price_tp=0;
   double point=MarketInfo(instrument,MODE_POINT); // getting the value of 1 point for the instrument
   datetime expiry=0;
   int order_type=-1;
   RefreshRates();
   //simplifying the arguments for the function by only allowing OP_BUY and OP_SELL 
   if(cmd==OP_BUY)
     {
      if(distanceFromCurrentPrice>0) order_type=OP_BUYSTOP; // If the distanceFromCurrentPrice is >0 the function enters the order above the current price.
      else if(distanceFromCurrentPrice<0) order_type=OP_BUYLIMIT;
      else order_type=OP_BUY;
      if(order_type==OP_BUY) distanceFromCurrentPrice=0;
      entryPrice=MarketInfo(instrument,MODE_ASK)+distanceFromCurrentPrice*point;
      if(!market)
        {
         if(sl>0) price_sl=entryPrice-sl*point;
         if(tp>0) price_tp=entryPrice+tp*point;
        }
     }
   else if(cmd==OP_SELL)
     {
      if(distanceFromCurrentPrice>0) order_type=OP_SELLLIMIT; //If the distanceFromCurrentPrice is >0 the function enters the order below the current price.
      else if(distanceFromCurrentPrice<0) order_type=OP_SELLSTOP;
      else order_type=OP_SELL;
      if(order_type==OP_SELL) distanceFromCurrentPrice=0;
      entryPrice=MarketInfo(instrument,MODE_BID)+distanceFromCurrentPrice*point;
      if(!market)
        {
         if(sl>0) price_sl=entryPrice+sl*point;
         if(tp>0) price_tp=entryPrice-tp*point;
        }
     }
   if(order_type<0) return 0;
   else  if(order_type==0 || order_type==1) expiry=0;
   else if(expire>0)
      expiry=(datetime)MarketInfo(instrument,MODE_TIME)+expire;
   if(market)
     {
      int ticket=OrderSend(instrument,order_type,lots,entryPrice,entering_max_slippage,0,0,comment,magic,expiry,a_clr);
      if(ticket>0)
        {
         if(OrderSelect(ticket,SELECT_BY_TICKET))
           {
            if(cmd==OP_BUY)
              {
               if(sl>0) price_sl=OrderOpenPrice()-sl*point;
               if(tp>0) price_tp=OrderOpenPrice()+tp*point;
              }
            else if(cmd==OP_SELL)
              {
               if(sl>0) price_sl=OrderOpenPrice()+sl*point;
               if(tp>0) price_tp=OrderOpenPrice()-tp*point;
              }
            bool result=modify(ticket,price_sl,price_tp);
           }
        }
      return ticket;
     }
   return OrderSend(instrument,order_type,lots,entryPrice,entering_max_slippage,price_sl,price_tp,comment,magic,expiry,a_clr);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

int entry(string instrument,int cmd,double lots,int distanceFromCurrentPrice,int sl,int tp,string comment=NULL,int magic=0,int expire=0,color a_clr=clrNONE,bool market=false,int retries=3,int sleep=500)
  {
   int ticket=0;
   for(int i=0;i<retries;i++)
     {
      if(IsStopped()) Print("Expert was stopped");
      else if(!IsConnected()) Print("No internet connection");
      else if(!IsExpertEnabled()) Print("Experts not enabled in trading platform");
      else if(IsTradeContextBusy()) Print("Trade context is busy");
      else if(!IsTradeAllowed()) Print("Trade is not allowed in trading platform");
      else ticket=send_order(instrument,cmd,lots,distanceFromCurrentPrice,sl,tp,comment,magic,expire,a_clr,market);
      if(ticket>0)
         break;
      else Print("Error in sending order ("+IntegerToString(GetLastError(),0)+"), retry: "+IntegerToString(i,0)+"/"+IntegerToString(retries));
      Sleep(sleep);
     }
   return ticket;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

bool trailingstop_check_order(int ticket,int trail,int threshold,int step)
  {
   if(ticket<=0) return true;
   if(!OrderSelect(ticket,SELECT_BY_TICKET)) return false;
   int digits=(int) MarketInfo(OrderSymbol(),MODE_DIGITS);
   double point=MarketInfo(OrderSymbol(),MODE_POINT);
   bool result=true;
   if(OrderType()==OP_BUY)
     {
      double newsl=OrderClosePrice()-trail*point;
      double activation=OrderOpenPrice()+threshold*point;
      double activation_sl=activation-(trail*point);
      double step_in_pts=newsl-OrderStopLoss();
      if(OrderStopLoss()==0|| compare_doubles(activation_sl,OrderStopLoss(),digits)>0)
        {
         if(compare_doubles(OrderClosePrice(),activation,digits)>=0)
            result=modify(ticket,activation_sl);
        }
      else if(compare_doubles(step_in_pts,step*point,digits)>=0)
        {
         result=modify(ticket,newsl);
        }
     }
   else if(OrderType()==OP_SELL)
     {
      double newsl=OrderClosePrice()+trail*point;
      double activation=OrderOpenPrice()-threshold*point;
      double activation_sl=activation+(trail*point);
      double step_in_pts=OrderStopLoss()-newsl;
      if(OrderStopLoss()==0|| compare_doubles(activation_sl,OrderStopLoss(),digits)<0)
        {
         if(compare_doubles(OrderClosePrice(),activation,digits)<=0)
            result=modify(ticket,activation_sl);
        }
      else if(compare_doubles(step_in_pts,step*point,digits)>=0)
        {
         result=modify(ticket,newsl);
        }
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void trailingstop_check(int trail,int threshold,int step,int magic=-1)
  {
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS))
        {
         if(magic==-1 || magic==OrderMagicNumber())
            trailingstop_check_order(OrderTicket(),trail,threshold,step);
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

int signal_add(int current,int add,bool exit=false)
  {
   if(current==TRADE_SIGNAL_VOID)
      return current;
   else if(current==TRADE_SIGNAL_NEUTRAL)
      return add;
   else
     {
      if(add==TRADE_SIGNAL_NEUTRAL)
         return current;
      else if(add==TRADE_SIGNAL_VOID)
         return add;
      else if(add!=current)
        {
         if(exit)
            return TRADE_SIGNAL_VOID;
         else
            return TRADE_SIGNAL_NEUTRAL;
        }
     }
   return add;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

double mm(MM method,string instrument,double lots,int sl,double risk_mm1,double lots_mm2,double per_mm2,double risk_mm3,double risk_mm4)
  {
   double balance=AccountBalance();
   double tick_value=MarketInfo(instrument,MODE_TICKVALUE);
   
   switch(method)
     {
      case MM_RISK_PERCENT:
         if(sl>0) lots=((balance*risk_mm1)/sl)/tick_value;
         break;
      case MM_FIXED_RATIO:
         lots=balance*lots_mm2/per_mm2;
         break;
      case MM_FIXED_RISK:
         if(sl>0) lots=(risk_mm3/tick_value)/sl;
         break;
      case MM_FIXED_RISK_PER_POINT:
         lots=risk_mm4/tick_value;
         break;
     }
   double min_lot=MarketInfo(instrument,MODE_MINLOT);
   double max_lot=MarketInfo(instrument,MODE_MAXLOT);
   int lot_digits=(int) -MathLog10(MarketInfo(instrument,MODE_LOTSTEP));
   lots=NormalizeDouble(lots,lot_digits);
   if(lots<min_lot) lots=min_lot;
   if(lots>max_lot) lots=max_lot;
   return lots;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

bool is_new_bar(string instrument,int tf,bool wait=false)
  {
   static datetime bar_time=0;
   static double open_price=0;
   datetime current_bar_time=iTime(instrument,tf,0);
   double current_open_price=iOpen(instrument,tf,0);
   int digits=(int)MarketInfo(instrument,MODE_DIGITS);
   if(bar_time==0 && open_price==0)
     {
      bar_time=current_bar_time;
      open_price=current_open_price;
      if(wait)
         return false;
      else return true;
     }
   else if(current_bar_time>bar_time && 
      compare_doubles(open_price,current_open_price,digits)!=0)
        {
         bar_time=current_bar_time;
         open_price=current_open_price;
         return true;
        }
      return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

int count_orders(ENUM_ORDER_SET type=-1,int magic=-1)
  {
   int count=0;
   for(int i=OrdersTotal();i>=0;i--)
     {
      if(OrderSelect(i,SELECT_BY_POS))
        {
         if(magic==-1 || magic==OrderMagicNumber())
           {
            int ordertype=OrderType();
            int ticket=OrderTicket();
            switch(type)
              {
               case ORDER_SET_BUY:
                  if(ordertype==OP_BUY) count++;
                  break;
               case ORDER_SET_SELL:
                  if(ordertype==OP_SELL) count++;
                  break;
               case ORDER_SET_BUY_LIMIT:
                  if(ordertype==OP_BUYLIMIT) count++;
                  break;
               case ORDER_SET_SELL_LIMIT:
                  if(ordertype==OP_SELLLIMIT) count++;
                  break;
               case ORDER_SET_BUY_STOP:
                  if(ordertype==OP_BUYSTOP) count++;
                  break;
               case ORDER_SET_SELL_STOP:
                  if(ordertype==OP_SELLSTOP) count++;
                  break;
               case ORDER_SET_LONG:
                  if(ordertype==OP_BUY || ordertype==OP_BUYLIMIT || ordertype==OP_BUYSTOP)
                  count++;
                  break;
               case ORDER_SET_SHORT:
                  if(ordertype==OP_SELL || ordertype==OP_SELLLIMIT || ordertype==OP_SELLSTOP)
                  count++;
                  break;
               case ORDER_SET_LIMIT:
                  if(ordertype==OP_BUYLIMIT || ordertype==OP_SELLLIMIT)
                  count++;
                  break;
               case ORDER_SET_STOP:
                  if(ordertype==OP_BUYSTOP || ordertype==OP_SELLSTOP)
                  count++;
                  break;
               case ORDER_SET_MARKET:
                  if(ordertype<=1) count++;
                  break;
               case ORDER_SET_PENDING:
                  if(ordertype>1) count++;
                  break;
               default: count++;
              }
           }
        }
     }
   return count;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

bool is_time_in_range(datetime time,int start_hour,int start_min,int end_hour,int end_min,int gmt_offset=0)
  {
   if(gmt_offset!=0)
     {
      start_hour+=gmt_offset;
      end_hour+=gmt_offset;
     }
   if(start_hour>23) start_hour=(start_hour-23)-1;
   else if(start_hour<0) start_hour=23+start_hour+1;
   if(end_hour>23) end_hour=(end_hour-23)-1;
   else if(end_hour<0) end_hour=23+end_hour+1;
   int hour=TimeHour(time);
   int minute=TimeMinute(time);
   int t=(hour*3600)+(minute*60);
   int s=(start_hour*3600)+(start_min*60);
   int e=(end_hour*3600)+(end_min*60);
   if(s==e)
      return true;
   else if(s<e)
     {
      if(t>=s && t<e)
         return true;
     }
   else if(s>e)
     {
      if(t>=s || t<e)
         return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

bool virtualstop_check_order(int ticket,int sl,int tp)
  {
   if(ticket<=0) return true;
   if(!OrderSelect(ticket,SELECT_BY_TICKET)) return false;
   int digits=(int) MarketInfo(OrderSymbol(),MODE_DIGITS);
   double point=MarketInfo(OrderSymbol(),MODE_POINT);
   bool result=true;
   if(OrderType()==OP_BUY)
     {
      double virtual_stoploss=OrderOpenPrice()-sl*point;
      double virtual_takeprofit=OrderOpenPrice()+tp*point;
      if((sl>0 && compare_doubles(OrderClosePrice(),virtual_stoploss,digits)<=0) || 
         (tp>0 && compare_doubles(OrderClosePrice(),virtual_takeprofit,digits)>=0))
        {
         result=exit_order(ticket);
        }
     }
   else if(OrderType()==OP_SELL)
     {
      double virtual_stoploss=OrderOpenPrice()+sl*point;
      double virtual_takeprofit=OrderOpenPrice()-tp*point;
      if((sl>0 && compare_doubles(OrderClosePrice(),virtual_stoploss,digits)>=0) || 
         (tp>0 && compare_doubles(OrderClosePrice(),virtual_takeprofit,digits)<=0))
        {
         result=exit_order(ticket);
        }
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void virtualstop_check(int sl,int tp,int magic=-1)
  {
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS))
         if(magic==-1 || magic==OrderMagicNumber())
            virtualstop_check_order(OrderTicket(),sl,tp);
     }
  }
  
//+------------------------------------------------------------------+