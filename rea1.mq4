//+------------------------------------------------------------------+
//|                                            Relativity_EA_V01.mq4 |
//|                                                 Quant FX Capital |
//|                                   https://www.quantfxcapital.com |
//+------------------------------------------------------------------+
#property copyright "Quant FX Capital"
#property link      "https://www.quantfxcapital.com"
#property version   "3.00"
#property strict
//#property show_inputs // This can only be used for scripts. I added this because, by default, it will not show any external inputs. This is to override this behaviour so it deliberately shows the inputs.
// TODO: When strategy testing, make sure you have all the M5, D1, and W1 data because it is reference in the code.
// TODO: Always use NormalizeDouble() when computing the price (or lots or ADR?) yourself. This is not necessary for internal functions like OrderOPenPrice(), OrderStopLess(),OrderClosePrice(),Bid,Ask
// TODO: User the compare_doubles() function to compare two doubles.
// Remember: It has to be for a broker that will give you D1 data for at least around 6 months in order to calculate the ADR.
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum ENUM_TRADE_SIGNAL  // since ENUM_ORDER_TYPE is not enough, this enum was created to be able to use neutral and void signals
  {
   TRADE_SIGNAL_VOID=-1, // exit all trades
   TRADE_SIGNAL_NEUTRAL, // no direction is determined. This happens when buy and sell signals are compared with each other.
   TRADE_SIGNAL_BUY, // buy
   TRADE_SIGNAL_SELL // sell
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum ENUM_ORDER_SET
  {
   ORDER_SET_ALL=-1,
   ORDER_SET_BUY, // =0
   ORDER_SET_SELL, // =1
   ORDER_SET_BUY_LIMIT, // =2
   ORDER_SET_SELL_LIMIT, // =...
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
enum MM // Money Management
  {
   MM_FIXED_LOT, // 0 by default
   MM_RISK_PERCENT,
   MM_FIXED_RATIO,
   MM_FIXED_RISK,
   MM_FIXED_RISK_PER_POINT,
  };

//ontick()
	int charts_timeframe=PERIOD_M5;
	string symbol=NULL;
	int virtual_sl=0; // TODO: Change to a percent of ADR
	int virtual_tp=0; // TODO: Change to a percent of ADR
	
   // Breakeven variables
	int breakeven_threshold=500; // TODO: Change this to a percent of ADR. The percent of ADR in profit before setting the stop to breakeven.
	int breakeven_plus=0; // plus allows you to move the stoploss +/- from the entry price where 0 is breakeven, <0 loss zone, and >0 profit zone
	
//trailing stop variables
	int trail_value=20; // TODO: Change to a percent of ADR
	int trail_threshold=500; // TODO: Change to a percent of ADR
	int trail_step=20; // the minimum difference between the proposed new value of the stoploss to the current stoploss price // TODO: Change to a percent of ADR
	
	input bool exit_opposite_signal=true; // Should the EA exit trades when there is a signal in the opposite direction?
	input int max_directional_trades=1; // How many trades can the EA enter at the same time on the current chart? TODO: make sure you can have 1 long and 1 short at the same time.
	input bool entry_new_bar=false; // Should you only enter trades when a new bar begins?
	input bool wait_next_bar_on_load=true; // When you load the EA, should it wait for the next bar to load before giving the EA the ability to enter a trade?
	
//time filters - only allow EA to enter trades between a range of time in a day
	input int start_time_hour=0; // eligible time to start a trade. 0-23
	input int start_time_minute=30; // 0-59
	input int end_time_hour=23; // banned time to start a trade. 0-23
	input int end_time_minute=0; // 0-59
	input int gmt_hour_offset=-3; // The value of 0 refers to the time zone used by the broker (seen as 0:00 on the chart). Adjust this offset hour value if the broker's 0:00 server time is not equal to when the time the NY session ends their trading day.

   input int exit_time_hour=23; // the exit_time should be before the trading range start_time and after trading range end_time
   input int exit_time_minute=30;
   
//enter_order
	input double takeprofit_percent=0.3; // Must be a positive number. // TODO: Change to a percent of ADR (What % of ADR should you tarket?)
   input double stoploss_percent=1.0; // Must be a positive number.
	input double pullback_percent=-0.50; //  If you want a limit order, it must be negative. If you want a stop order, it must be positive.
	input double max_spread_percent=.04; // Must be positive. What percent of ADR should the spread be less than? (Only for immediate orders and not pending.)
	
	input int entering_max_slippage=5; // TODO: Change to a percent of ADR  // the default used to be 50 // TODO: allow slippage in my favor but not against me
	//input int unfavorable_slippage=5;
	input string order_comment="Relativity EA"; // TODO: Add the parameter settings for the order to the message. // allows the robot to enter a description for the order. An empty string is a default value.
	input int order_expire=// In seconds. If none, type 0. The expiration countdown is only used for pending orders.
	   /*Minutes=**/120
	   *
	   /*Seconds in a minute=*/60; 
	input bool market_exec=false; // False means that it is instant execution rather than market execution. Not all brokers offer market execution. The rule of thumb is to never set it as instant execution if the broker only provides market execution.
	input bool long_allowed=true;
	input bool short_allowed=false; // TODO: set this back to true once you have all of the shorting code done
	input color arrow_color_short=clrRed; // you may want to remove all arrow color settings
	input color arrow_color_long=clrGreen; // you may want to remove all arrow color settings
	
//exit_order
	input int exiting_max_slippage=50; // TODO: Change to a percent of ADR // additional argument i added


	
//calculate_lots/mm variables
	input double lot_size=0.1;
	MM money_management=MM_RISK_PERCENT;
	double mm1_risk_percent=0.02; // percent risked when using the MM_RISK_PERCENT money management calculations
	double mm2_lots=0.1;
	double mm2_per=1000;
	double mm3_risk=50;
	double mm4_risk=50;
	
// ADR()
   input double change_ADR_percent=-.25;
   input int num_ADR_months=2; // How months back should you use to calculate the average ADR? (Divisible by 1) TODO: this is not implemented yet.
   input double above_ADR_outlier_percent=2; // How much should the ADR be surpassed an a day for it to be neglected from the average calculation? TODO: This is not implemented yet.
   input double below_ADR_outlier_percent=.25;

// Market Trends
   input int H1s_to_roll=3; // How many hours should you roll to determine a short term market trend? (You are only allowed to input values divisible by 0.5.)
   input double max_weekend_gap_percent=.1; // What is the maximum weekend gap (as a percent of ADR) for H1s_to_roll to not take the previous week into account?
   input bool include_last_week=true; // Should the EA take Friday's moves into account when starting to determine length of the current move?

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
// Runs once when the EA is turned on

static int ADR_pips; // TODO: make sure this maintains the value that was generated OnInit()
static int order_magic; // An EA can only have one magic number. Used to identify the EA that is managing the order. TODO: see if it can auto generate the magic number every time the EA is loaded on the chart.

int generate_magic()
{
   MathSrand(1);
   int large_random_num=MathRand()*MathRand();
   
   while(magic_num_in_use(large_random_num))
   {
     large_random_num=MathRand()*MathRand(); // from 1 through 1,073,676,289
   }
   return large_random_num;
}

bool magic_num_in_use(int num)
{

   return false;
}
int OnInit()
  {
   order_magic=generate_magic();
   int range_start_time=(start_time_hour*3600)+(start_time_minute*60);
   int range_end_time=(end_time_hour*3600)+(end_time_minute*60);
   int exit_time=(exit_time_hour*3600)+(exit_time_minute*60);
      if(exit_time>range_start_time && exit_time<range_end_time)
        {
         Alert("Make sure that the trade exit_time_hour and exit_time_minute combination does not fall within the trading range start and end times or else there will be trouble!");
         return(INIT_FAILED);
        }
      else 
        {
         Alert("The initialization succeeded.");
         return(INIT_SUCCEEDED);
        }
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
// Runs once when the EA is turned off
void OnDeinit(const int reason)
  {
    return;
  }
  
double OnTester()
  {
    return 0;
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+

// Runs on every tick
void OnTick()
  {
   static bool adr_generated=false;
   static bool in_time_range=false;
   bool is_new_M5_bar=is_new_bar(symbol,PERIOD_M5,wait_next_bar_on_load); // this will run on every tick
   datetime current_time=TimeCurrent();

      if(is_new_M5_bar) // only check if it is in the time range once the EA is loaded and then every 5 minutes afterward
        {
         in_time_range=in_time_range(current_time,start_time_hour,start_time_minute,end_time_hour,end_time_minute,gmt_hour_offset);  
         
         if(in_time_range && !adr_generated) 
           {
            ADR_pips=get_ADR();
            if(ADR_pips>0) 
              {
               adr_generated=true; // the ADR will generate and won't generate again until after the cycle of not being in the time range completes
              }
            else 
              {
               adr_generated=false;
               return;
              }
           }
        }
 
      if(in_time_range && adr_generated)
        {
         // entry and exit signals
         int max_trades=max_directional_trades;
         int enter_signal=0,exit_signal=0;
         
         enter_signal=signal_entry();  
         exit_signal=signal_exit();
      
         // exit signal logic
         if(exit_signal==TRADE_SIGNAL_VOID)
           {
            close_all(); // close all pending and orders for the specific EAs orders
           }
         else if(exit_signal==TRADE_SIGNAL_BUY)
           {
            close_all_short();
           }
         else if(exit_signal==TRADE_SIGNAL_SELL)
           {
            close_all_long();
           }
      
         // entry signal logic
         int long_order_count=0, short_order_count=0;
         if(enter_signal>0) // if there is a signal to enter a trade
           {
            if(enter_signal==TRADE_SIGNAL_BUY)
              {
               if(exit_opposite_signal) exit_all_trades_set(ORDER_SET_SELL,order_magic);
               long_order_count=count_orders(ORDER_SET_LONG,order_magic); // counts all long (active and pending) orders for the current EA
               if(long_order_count<max_trades) // if you have not yet reached the user's maximum allowed long trades
                 {
                  if(!entry_new_bar || 
                     (entry_new_bar && is_new_M5_bar))
                        try_to_enter_order(OP_BUY);
                 }
              }
            else if(enter_signal==TRADE_SIGNAL_SELL)
              {
               if(exit_opposite_signal) exit_all_trades_set(ORDER_SET_BUY,order_magic);
               short_order_count=count_orders(ORDER_SET_SHORT,order_magic); // counts all short (active and pending) orders for the current EA
               if(short_order_count<max_trades) // if you have not yet reached the user's maximum allowed short trades
                 {
                  if(!entry_new_bar || 
                     (entry_new_bar && is_new_M5_bar))
                        try_to_enter_order(OP_SELL);
                 }
              }
           }
      
      // Breakeven (comment out if this functionality is not required)
      //if(breakeven_threshold>0) breakeven_check_all_orders(breakeven_threshold,breakeven_plus,order_magic);
      
      // Trailing Stop (comment out of this functinoality is not required)
      //if(trail_value>0) trailingstop_check_all_orders(trail_value,trail_threshold,trail_step,order_magic);
      //   virtualstop_check(virtual_sl,virtual_tp);     
        }     
       else
        {
          adr_generated=false; // making sure to set it to false so when the time is within the time range again, the ADR can get generated.
          bool time_to_exit=time_to_exit(current_time,exit_time_hour,exit_time_minute,gmt_hour_offset);
          if(time_to_exit) close_all(); // this is the special case where you can exit open and pending trades based on a specified time (this should have been set to be outside of the trading time range)
        } 
    
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

int ADR_calculation()
{
//   int six_mnth_num_days=6*22; 
   int three_mnth_sunday_count=0;
   int three_mnth_num_days=3*22; // There are about 22 business days a month.   
   
   for(int i=three_mnth_num_days;i>0;i--) // count the number of Sundays in the past 6 months
      {
      int day=DayOfWeek();
      
      if(day==0) // count Sundays
        {
         three_mnth_sunday_count++;
        }
      }
   double avg_sunday_per_day=three_mnth_sunday_count/three_mnth_num_days;
   int six_mnth_adjusted_num_days=(int)(((avg_sunday_per_day*three_mnth_num_days)+three_mnth_num_days)*2); // accurately estimate how many D1 bars you would have to go back to get the desired number of days to look back
   int six_mnth_non_sunday_count=0;
   double six_mnth_non_sunday_ADR_sum=0;
   
   for(int i=six_mnth_adjusted_num_days;i>0;i--) // get the raw ADR (outliers are included but not Sunday's outliers) for the approximate past 6 months
   {
    int day=DayOfWeek();
   
    if(day>0) // if the day of week is not Sunday
      {
       double HOD=iHigh(symbol,PERIOD_D1,i);
       double LOD=iLow(symbol,PERIOD_D1,i);
       six_mnth_non_sunday_ADR_sum+=HOD-LOD;
       six_mnth_non_sunday_count++;
      }
   }
   
   int digits=(int)MarketInfo(symbol,MODE_DIGITS);
   double six_mnth_ADR_avg=NormalizeDouble(six_mnth_non_sunday_ADR_sum/six_mnth_non_sunday_count,digits); // the first time getting the ADR average
   six_mnth_non_sunday_ADR_sum=0;
   six_mnth_non_sunday_count=0;
   
   for(int i=six_mnth_adjusted_num_days;i>0;i--) // refine the ADR (outliers and Sundays are NOT included) for the approximate past 6 months
     {
      int day=DayOfWeek();
           
      if(day>0) // if the day of week is not Sunday
        {
         double HOD=iHigh(symbol,PERIOD_D1,i);
         double LOD=iLow(symbol,PERIOD_D1,i);
         double days_range=HOD-LOD;
         double ADR_ratio=NormalizeDouble(days_range/six_mnth_ADR_avg,2); // ratio for comparing the current iteration with the 6 month average
         
         if(compare_doubles(ADR_ratio,below_ADR_outlier_percent,2)==1 && compare_doubles(ADR_ratio,above_ADR_outlier_percent,2)==-1) // filtering out outliers
           {
            six_mnth_non_sunday_ADR_sum+=days_range;
            six_mnth_non_sunday_count++;
           }
        }
     }
   six_mnth_ADR_avg=NormalizeDouble(six_mnth_non_sunday_ADR_sum/six_mnth_non_sunday_count,digits); // the second time getting an ADR average but this time it is MORE REFINED
   double x_mnth_non_sunday_ADR_sum=0;
   int x_mnth_non_sunday_count=0;
   int x_mnth_num_days=num_ADR_months*22; // There are about 22 business days a month.
   int x_mnth_adjusted_num_days=(int)((avg_sunday_per_day*x_mnth_num_days)+x_mnth_num_days); // accurately estimate how many D1 bars you would have to go back to get the desired number of days to look back
   
   for(int i=x_mnth_adjusted_num_days;i>0;i--) // find the counts of all days that are significantly below or above ADR
     {
      int day=DayOfWeek();
           
      if(day>0) // if the day of week is not Sunday
        {
         double HOD=iHigh(symbol,PERIOD_D1,i);
         double LOD=iLow(symbol,PERIOD_D1,i);
         double days_range=HOD-LOD;
         double ADR_ratio=NormalizeDouble(days_range/six_mnth_ADR_avg,2); // ratio for comparing the current iteration with the 6 month average
         
         if(compare_doubles(ADR_ratio,below_ADR_outlier_percent,2)==1 && compare_doubles(ADR_ratio,above_ADR_outlier_percent,2)==-1) // filtering out outliers
           {
            x_mnth_non_sunday_ADR_sum+=days_range;
            x_mnth_non_sunday_count++;
           }
        }
     }
   // adr doesn't need to be Normalized because it has been converted into an int.
   int adr=(int)((x_mnth_non_sunday_ADR_sum/Point)/x_mnth_non_sunday_count); // converting it away from points to more human understandable numbers
   // int adr=.0080;
   if(change_ADR_percent==0 || change_ADR_percent==NULL) return adr;
   else return (int)((adr*change_ADR_percent)+adr); // include the ability to increase\decrease the ADR by a certain percentage where the input is a global variable
}

int get_ADR() // get the Average Daily Range
{
   static int adr=0;
   bool is_new_D1_bar=is_new_bar(symbol,PERIOD_D1,false);
   
   if(adr==0) // if it is the first time the function is called
     {
     int calculated_adr=ADR_calculation();
     adr=calculated_adr; // make the function remember the calculation the next time it is called
     return adr;
     }
   if(is_new_D1_bar) // if it is a fresh new bar
     {
      int freshly_calculated_adr=ADR_calculation();
      adr=freshly_calculated_adr; // make the function remember the calculation the next time it is called
     }
   return adr; // if it is not the first time the function is called it is the middle of a bar, return the static adr
}
  
int get_start_bar()
{
   datetime week_start_open_time=iTime(symbol,PERIOD_W1,0)+(gmt_hour_offset*3600); // The iTime of the week bar gives you the time that the week is 0:00 on the chart so I shifted the time to start when the markets actually start.
   int week_start_bar=iBarShift(symbol,PERIOD_M5,week_start_open_time,false);
   int move_start_bar=H1s_to_roll*12;
      
   if(move_start_bar<=week_start_bar)
     {
      return move_start_bar;
     }
   else if(include_last_week)
     {
      double weekend_gap_points=MathAbs(iClose(symbol,PERIOD_W1,1)-iOpen(symbol,PERIOD_W1,0));
      double max_weekend_gap_points=NormalizeDouble((ADR_pips*Point)*max_weekend_gap_percent,Digits); // TODO: this may not need to be normalized
      
      if(weekend_gap_points>=max_weekend_gap_points) return week_start_bar;
      else return move_start_bar;
     }
   else
     {
      return week_start_bar;
     }
}

double periods_pivot_price(string mode)
{
   if(mode=="Buying") return iLow(symbol,PERIOD_M5,iLowest(symbol,PERIOD_M5,MODE_LOW,WHOLE_ARRAY,get_start_bar())); // get the price of the bar that has the lowest price for the determined period
   else if(mode=="Selling") return iHigh(symbol,PERIOD_M5,iHighest(symbol,PERIOD_M5,MODE_HIGH,WHOLE_ARRAY,get_start_bar())); // get the price of the bar that has the highest price for the determined period
   else return -1;
}


double uptrend_ADR_triggered_price()
{
   static double LOP=periods_pivot_price("Buying");
   double point=MarketInfo(symbol,MODE_POINT);
   double pip_move_threshold=ADR_pips*Point;
   double current_bid=Bid;   
   
   if(LOP==-1) // this part is necessary in case periods_pivot_price ever returns 0
     {
       return -1;
     }
   else if(current_bid<LOP) // if the low of the range was surpassed
     {
       // since the bottom of the range was surpassed, you have to reset the LOP. You might as well take this opportunity to take the period into account.
       LOP=periods_pivot_price("Buying");
       return -1;
     } 
   else if(current_bid-LOP>=pip_move_threshold) // if the pip move meets or exceed the ADR_Pips in points, return the current bid. Note: this will return true over and over again
     {
       // since the top of the range was surpassed and a pending order would be created, this is a good opportunity to update the LOP since you can't just leave it as the static value constantly
       LOP=periods_pivot_price("Buying");
       if(current_bid-LOP>=pip_move_threshold) return current_bid; // check if it is actually true by taking the new calculation of Low Of Period into account
       else return -1;
     }         
   else return -1;
}

double downtrend_ADR_triggered_price()
{
   static double HOP=periods_pivot_price("Selling");
   double point=MarketInfo(symbol,MODE_POINT);
   double pip_move_threshold=ADR_pips*point;
   double current_bid=Bid;
   
   if(HOP==-1) // this part is necessary in case periods_pivot_price ever returns 0
     {
       return -1;
     }
   else if(current_bid>HOP) // if the low of the range was surpassed
     {
       // since the bottom of the range was surpassed, you have to reset the LOP. You might as well take this opportunity to take the period into account.
       HOP=periods_pivot_price("Selling");
       return -1;
     } 
   else if(HOP-current_bid>=pip_move_threshold) // if the pip move meets or exceed the ADR_Pips in points, return the current bid. Note: this will return true over and over again
     {
       // since the top of the range was surpassed and a pending order would be created, this is a good opportunity to update the LOP since you can't just leave it as the static value constantly
       HOP=periods_pivot_price("Selling");
       if(HOP-current_bid>=pip_move_threshold) return current_bid; // check if it is actually true by taking the new calculation of Low Of Period into account
       else return -1;
     }         
   else return -1;
}


int signal_pullback_after_ADR_triggered()
   {
   int signal=TRADE_SIGNAL_NEUTRAL;
   if(uptrend_ADR_triggered_price()>0) return signal=TRADE_SIGNAL_BUY;
   // for a buying signal, take the level that adr was triggered and subtract the pullback_pips to get the pullback_entry_price
   // if the pullback_entry_price is met or exceeded, signal = TRADE_SIGNAL_BUY
   
   else if(downtrend_ADR_triggered_price()>0) return signal=TRADE_SIGNAL_SELL;
   
   else return signal;
   }
   
bool time_to_exit(datetime current_time,int hour,int min,int gmt_offset=0) 
{
   if(gmt_offset!=0) 
     {
      hour+=gmt_offset;
      hour+=gmt_offset;
     }
// Since a non-zero gmt_offset will make the start and end hour go beyond acceptable paremeters (below 0 or above 23), change the start_hour and end_hour to military time.
   if(hour>23) hour=(hour-23)-1;
   else if(hour<0) hour=23+hour+1;
   
   int timehour=TimeHour(current_time);
   int timeminute=TimeMinute(current_time);
   int exit_hour=hour*3600;
   int exit_min=min*60;
   
   if(timehour==exit_hour && timeminute==exit_min) return true; // this will only give the signal to exit for every tick for 1 minute per day
   else return false;
}
  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// Checks for the entry of orders
int signal_entry() // gets called for every tick
  {
   int signal=TRADE_SIGNAL_NEUTRAL;
   
/* Add 1 or more entry signals below. 
   With more than 1 signal, you would follow this code using the signal_compare function. 
   "signal=signal_compare(signal,signal_pullback_after_ADR_triggered());"
   As each signal is compared with the previous signal, the signal variable will change and then the final signal wil get returned.
*/ 
   signal=signal_pullback_after_ADR_triggered();
   return signal;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// Checks for the exit of orders
int signal_exit()
  {
   int signal=TRADE_SIGNAL_NEUTRAL;
// Add exit signals below. As each signal is compared with the previous signal, the signal variable will change and then get returned.
// The 3rd argument of the signal_compare function should explicitely be set to "true" every time.



// Return the exit signal
   return signal;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

double calculate_lots()
  {
   double stoploss_pips=NormalizeDouble(ADR_pips*stoploss_percent,2);
   double lots=mm(money_management,
                  symbol,
                  lot_size,
                  stoploss_pips,
                  mm1_risk_percent,
                  mm2_lots,
                  mm2_per,
                  mm3_risk,
                  mm4_risk);
   return lots;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void try_to_enter_order(ENUM_ORDER_TYPE type)
  {
   double distance_pips;
   color arrow_color;
   
   if(pullback_percent==0 || pullback_percent==NULL) distance_pips=0;
   else distance_pips=NormalizeDouble(ADR_pips*pullback_percent,2);
   
   if(type==OP_BUY /*|| type==OP_BUYSTOP || type==OP_BUYLIMIT*/) // what is the point of checking if it is a buystop or sellstop if the only type that gets sent to this function is OP_BUY?
     {
      if(!long_allowed) return;
      distance_pips=distance_pips*-1; // there are scenerios where this can be 0*-1=0
      arrow_color=arrow_color_long;
     }
   else if(type==OP_SELL /*|| type==OP_SELLSTOP || type==OP_SELLLIMIT*/)
     {
      if(!short_allowed) return;
      arrow_color=arrow_color_short;
     }
   else return;
      
   double lots=calculate_lots();

   // remember that you could add more arguments to the end instead of accepting the defaults of the check_for_entry_errors function
   check_for_entry_errors(symbol,
               type,
               lots,
               distance_pips, // This used to be 0 because it was originally for opening a market order.
               NormalizeDouble(ADR_pips*stoploss_percent,2),
               NormalizeDouble(ADR_pips*takeprofit_percent,2),
               order_comment,
               order_magic,
               order_expire,
               arrow_color,
               market_exec); 
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void close_all()
  {
   exit_all_trades_set(ORDER_SET_ALL,order_magic);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void close_all_long()
  {
   exit_all_trades_set(ORDER_SET_BUY,order_magic); // ORDER_SET_BUY includes everything (pending and active) orders related to buying
//exit_all_trades_set(ORDER_SET_BUY_STOP,order_magic);
//exit_all_trades_set(ORDER_SET_BUY_LIMIT,order_magic);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void close_all_short()
  {
   exit_all_trades_set(ORDER_SET_SELL,order_magic); // ORDER_SET_SELL includes everything (pending and active) orders related to selling
//exit_all_trades_set(ORDER_SET_SELL_STOP,order_magic);
//exit_all_trades_set(ORDER_SET_SELL_LIMIT,order_magic);
  }

// Neutralizes situations where there is a conflict between the entry and exit signal.
// TODO: This function is not yet being called. Since the entry and exit signals are passed by reference, these paremeters would need to be prepared in advance and stored in variables prior to calling the function.
void signal_manage(ENUM_TRADE_SIGNAL &entry,ENUM_TRADE_SIGNAL &exit)
  {
   if(exit==TRADE_SIGNAL_VOID)                              entry=TRADE_SIGNAL_NEUTRAL;
   if(exit==TRADE_SIGNAL_BUY && entry==TRADE_SIGNAL_SELL)   entry=TRADE_SIGNAL_NEUTRAL;
   if(exit==TRADE_SIGNAL_SELL && entry==TRADE_SIGNAL_BUY)   entry=TRADE_SIGNAL_NEUTRAL;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

bool breakeven_check_order(int ticket,int threshold,int plus) 
  {
   if(ticket<=0) return true; // if it is a valid ticket, return true
   if(!OrderSelect(ticket,SELECT_BY_TICKET)) return false; // if there is no ticket, it cannot be process so return false
   int digits=(int)MarketInfo(OrderSymbol(),MODE_DIGITS); // how many digit broker
   double point=MarketInfo(OrderSymbol(),MODE_POINT); // get the point for the instrument
   bool result=true; // initialize the variable result
   double order_sl=OrderStopLoss();
   if(OrderType()==OP_BUY) // if it is a buy order
     {
      double new_sl=OrderOpenPrice()+(plus*point); // calculate the price of the new stoploss
      double profit_in_pts=OrderClosePrice()-OrderOpenPrice(); // calculate how many points in profit the trade is in so far
      if(order_sl==0 || compare_doubles(new_sl,order_sl,digits)==1) // if there is no stoploss or the potential new stoploss is greater than the current stoploss
         if(compare_doubles(profit_in_pts,threshold*point,digits)>=0) // if the profit in points so far > provided threshold, then set the order to breakeven
            result=modify(ticket,new_sl);
     }
   else if(OrderType()==OP_SELL)
     {
      double new_sl=OrderOpenPrice()-(plus*point);
      double profit_in_pts=OrderOpenPrice()-OrderClosePrice();
      if(order_sl==0 || compare_doubles(new_sl,order_sl,digits)==-1)
         if(compare_doubles(profit_in_pts,threshold*point,digits)>=0)
            result=modify(ticket,new_sl);
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void breakeven_check_all_orders(int threshold,int plus,int magic=-1) // a -1 magic number means the there is no magic number in this order or EA
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
// Checking if the order should be modified. If it should, then the order gets modified. The function returns true when it is done determining if it should modify. It may or may not if it determines it doesn't have to.
bool modify_order(int ticket,double sl,double tp=-1,double entryPrice=-1,datetime expire=0,color a_color=clrNONE)
  {
   bool result=false;
   if(OrderSelect(ticket,SELECT_BY_TICKET))
     {
      int digits=(int)MarketInfo(OrderSymbol(),MODE_DIGITS); // The count of digits after the decimal point.
      if(sl==-1) sl=OrderStopLoss(); // if stoploss is not changed from the default set in the argument
      else sl=NormalizeDouble(sl,digits);
      if(tp==-1) tp=OrderTakeProfit(); // if takeprofit is not changed from the default set in the argument
      else tp=NormalizeDouble(tp,digits); // it needs to be normalized since you calculated it yourself to prevent errors when modifying an order
      if(OrderType()<=1) // if it IS NOT a pending order
        {
        // to prevent Error Code 1, check if there was a change
        // compare_doubles returns 0 if the doubles are equal
         if(compare_doubles(sl,OrderStopLoss(),digits)==0 && 
            compare_doubles(tp,OrderTakeProfit(),digits)==0)
            return true; //terminate the function
         entryPrice=OrderOpenPrice();
        }
      else if(OrderType()>1) // if it IS a pending order
        {
         if(entryPrice==-1)
            entryPrice=OrderOpenPrice();
         else entryPrice=NormalizeDouble(entryPrice,digits); // it needs to be normalized since you calculated it yourself to prevent errors when modifying an order
         // to prevent error code 1, check if there was a change
         // compare_doubles returns 0 if the doubles are equal
         if(compare_doubles(entryPrice,OrderOpenPrice(),digits)==0 && 
            compare_doubles(sl,OrderStopLoss(),digits)==0 && 
            compare_doubles(tp,OrderTakeProfit(),digits)==0 && 
            expire==OrderExpiration())
            return true; //terminate the function
        }
      result=OrderModify(ticket,entryPrice,sl,tp,expire,a_color);
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// check for errors before modifying the order
bool modify(int ticket,double sl,double tp=-1,double entryPrice=-1,datetime expire=0,color a_color=clrNONE,int retries=3,int sleep=500)
  {
   bool result=false;
   if(ticket>0)
     {
      for(int i=0;i<retries;i++)
        {
         if(!IsConnected()) Print("There is no internet connection.");
         else if(!IsExpertEnabled()) Print("EAs are not enabled in the trading platform.");
         else if(IsTradeContextBusy()) Print("The trade context is busy.");
         else if(!IsTradeAllowed()) Print("The trade is not allowed in the trading platform.");
         else result=modify_order(ticket,sl,tp,entryPrice,expire,a_color);
         if(result)
            break;
         Sleep(sleep);
      // TODO: setup an email and SMS alert.
     Print(OrderSymbol()," , ",order_comment,", An order was attempted to be modified but it did not succeed. (",IntegerToString(GetLastError(),0),"), Retry: "+IntegerToString(i,0),"/"+IntegerToString(retries));
     Alert(OrderSymbol()," , ",order_comment,", An order was attempted to be modified but it did not succeed. Check the Journal tab of the Navigator window for errors.");
        }
     }
   else
   {   
      Print(OrderSymbol()," , ",order_comment,"Modifying the order was not successfull. The ticket couldn't be selected.");
   }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

int compare_doubles(double var1,double var2,int precision) // For the precision argument, often it is the number of digits after the price's decimal point.
  {
   double point=MathPow(10,-precision); // 10^(-precision) // MathPow(base, exponent value)
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
      if(OrderType()<=1) // if order type is an OP_BUY or OP_SELL (not a pending order). (OrderType() can be successfully called after a successful selection using OrderSelect())
        {
         result=OrderClose(ticket,OrderLots(),OrderClosePrice(),exiting_max_slippage,a_color); // current order
        }
      else if(OrderType()>1) // if it is a pending order
        {
         result=OrderDelete(ticket,a_color);  // pending order
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
      if(!IsConnected()) Print("There is no internet connection.");
      else if(!IsExpertEnabled()) Print("EAs are not enabled in the trading platform.");
      else if(IsTradeContextBusy()) Print("The trade context is busy.");
      else if(!IsTradeAllowed()) Print("The trade is not allowed in the trading platform.");
      else result=exit_order(ticket,a_color);
      if(result)
         break;
      // TODO: setup an email and SMS alert.
      // Make sure to use OrderSymbol() instead of symbol to get the instrument of the order.
      Print("Closing order# "+DoubleToStr(OrderTicket(),0)+" failed "+DoubleToStr(GetLastError(),0));
      Sleep(sleep);
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// TODO: Create a feature to exit_all at a specific time you have set as a extern variable


// By default, if the type and magic number is not supplied it is set to -1 so the function exits all orders (including ones from different EAs). But, there is an option to specify the type of orders when calling the function.
void exit_all(int type=-1,int magic=-1) 
  {
   for(int i=OrdersTotal();i>=0;i--) // it has to iterate through the array from the highest to lowest
     {
      if(OrderSelect(i,SELECT_BY_POS)) // if an open trade can be found
        {
         if((type==-1 || type==OrderType()) && (magic==-1 || magic==OrderMagicNumber()))
            exit(OrderTicket());
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// This is similar to the exit_all function except that it allows you to choose more sets  to close. It will iterate through all open trades and close them based on the order type and magic number
void exit_all_trades_set(ENUM_ORDER_SET type=-1,int magic=-1)  // -1 means all
  {
   for(int i=OrdersTotal();i>=0;i--)
     {
      if(OrderSelect(i,SELECT_BY_POS)) // if an open trade can be found
        {
         if(magic==OrderMagicNumber() || magic==-1) // if the open trade matches the magic number
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

bool acceptable_spread(string instrument)
{
   RefreshRates();
   double spread=MarketInfo(instrument,MODE_SPREAD); // already normalized. I put this check here because the rates were just refereshed.
   if(compare_doubles(spread,(ADR_pips*max_spread_percent)*Point,1)<=0) return true; // Keeps the EA from entering trades when the spread is too wide for market orders (but not pending orders). Note: It may never enter on exotic currencies (which is good automation).
   else return false;
}

// the distanceFromCurrentPrice parameter is used to specify what type of order you would like to enter
int send_and_get_order_ticket(string instrument,int cmd,double lots,double distanceFromCurrentPrice,double sl,double tp,string comment=NULL,int magic=0,int expire=0,color a_clr=clrNONE,bool market=false) // the "market" argument is to make this function compatible with brokers offering market execution. By default, it uses instant execution.
  {
   double entryPrice=0; 
   double price_sl=0; 
   double price_tp=0;
   bool instant_exec=!market;
   double point=MarketInfo(instrument,MODE_POINT); // getting the value of 1 point for the instrument
   datetime expire_time=0; // 0 means there is no expiration time for a pending order
   int order_type=-1; // -1 means there is no order because actual orders are >=0
   // simplifying the arguments for the function by only allowing OP_BUY and OP_SELL and letting logic determine if it is a market or pending order based off the distanceFromCurrentPrice variable
   if(cmd==OP_BUY) // logic for long trades
     {
      if(distanceFromCurrentPrice<0) order_type=OP_BUYLIMIT;
      else if(distanceFromCurrentPrice==0) order_type=OP_BUY;
      else if(distanceFromCurrentPrice>0) /*order_type=OP_BUYSTOP*/ return 0;
      if(order_type==OP_BUYLIMIT /*|| order_type==OP_BUYSTOP*/)
        {
         double LOP=periods_pivot_price("Buying"); // TODO: should you really call this function again?
         if(LOP<0) return 0;
         entryPrice=LOP+(ADR_pips*point)+(distanceFromCurrentPrice*point); // setting the entryPrice this way prevents setting your limit and stop orders based on the current price (which would have caused inaccurate setting of prices)
        }
      else if(order_type==OP_BUY)
        {
         if(acceptable_spread(instrument)) entryPrice=MarketInfo(instrument,MODE_ASK);// Keeps the EA from entering trades when the spread is too wide for market orders (but not pending orders). Note: It may never enter on exotic currencies (which is good automation).
         // TODO: create an alert informing the user that the trade was not executed because of the spread being too wide
         else return 0;
        }
      if(instant_exec) // if the user wants instant execution (which the system allows them to input sl and tp prices)
        {
         if(sl>0) price_sl=entryPrice-(sl*point); // check if the stoploss and take profit prices can be determined
         if(tp>0) price_tp=entryPrice+(tp*point);
        }
     }
   else if(cmd==OP_SELL) // logic for short trades
     {
      if(distanceFromCurrentPrice>0) order_type=OP_SELLLIMIT;
      else if(distanceFromCurrentPrice==0) order_type=OP_SELL;
      else if(distanceFromCurrentPrice<0) /*order_type=OP_SELLSTOP*/ return 0;
      if(order_type==OP_SELLLIMIT /*|| order_type==OP_SELLSTOP*/)
        {
         double HOP=periods_pivot_price("Selling"); // TODO: should you really call this function again?
         if(HOP<0) return 0;
         entryPrice=HOP-(ADR_pips*point)+(distanceFromCurrentPrice*point); // setting the entryPrice this way prevents setting your limit and stop orders based on the current price (which would have caused inaccurate setting of prices)
        }
      else if(order_type==OP_SELL)
        {
         if(acceptable_spread(instrument)) entryPrice=MarketInfo(instrument,MODE_BID); // Keeps the EA from entering trades when the spread is too wide for market orders (but not pending orders). Note: It may never enter on exotic currencies (which is good automation).
         // TODO: create an alert informing the user that the trade was not executed because of the spread being too wide         
         else return 0;
        }
      if(instant_exec) // if the user wants instant execution (which allows them to input the sl and tp prices)
        {
         if(sl>0) price_sl=entryPrice+(sl*point); // check if the stoploss and take profit prices can be determined
         if(tp>0) price_tp=entryPrice-(tp*point);
        }
     }
   if(order_type<0) return 0; // if there is no order
   else if(order_type==0 || order_type==1) expire_time=0; // if it is NOT a pending order, set the expire_time to 0 because it cannot have an expire_time
   else if(expire>0) // if the user wants pending orders to expire
   expire_time=(datetime)MarketInfo(instrument,MODE_TIME)+expire; // expiration of the order = current time + expire time
   if(market) // If the user wants market execution (which does NOT allow them to input the sl and tp prices), this will calculate the stoploss and takeprofit AFTER the order to buy or sell is sent.
     {
      int ticket=OrderSend(instrument,order_type,lots,entryPrice,entering_max_slippage,0,0,comment,magic,expire_time,a_clr);
      if(ticket>0) // if there is a valid ticket
        {
         if(OrderSelect(ticket,SELECT_BY_TICKET))
           {
            if(cmd==OP_BUY)
              {
               if(sl>0) price_sl=OrderOpenPrice()-(sl*point);
               if(tp>0) price_tp=OrderOpenPrice()+(tp*point);
              }
            else if(cmd==OP_SELL)
              {
               if(sl>0) price_sl=OrderOpenPrice()+(sl*point);
               if(tp>0) price_tp=OrderOpenPrice()-(tp*point);
              }
            bool result=modify(ticket,price_sl,price_tp);
           }
        }
      return ticket;
     }
   return OrderSend(instrument,order_type,lots,entryPrice,entering_max_slippage,price_sl,price_tp,comment,magic,expire_time,a_clr);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

int check_for_entry_errors(string instrument,int cmd,double lots,double distanceFromCurrentPrice,double sl,double tp,string comment=NULL,int magic=0,int expire=0,color a_clr=clrNONE,bool market=false,int retries=3,int sleep=500)
  {
   int ticket=0;
   for(int i=0;i<retries;i++)
     {
      if(IsStopped()) Print("The EA was stopped.");
      else if(!IsConnected()) Print("There is no internet connection.");
      else if(!IsExpertEnabled()) Print("EAs are not enabled in trading platform.");
      else if(IsTradeContextBusy()) Print("The trade context is busy.");
      else if(!IsTradeAllowed()) Print("The trade is not allowed in the trading platform.");
      else ticket=send_and_get_order_ticket(instrument,cmd,lots,distanceFromCurrentPrice,sl,tp,comment,magic,expire,a_clr,market);
      if(ticket>0)
         break;
      else
      { 
        // TODO: setup an email and SMS alert.
        Print(instrument," , ",order_comment,": An order was attempted but it did not succeed. If there are no errors here, market factors may not have met the code's requirements within the send_and_get_order_ticket function. (",IntegerToString(GetLastError(),0),"), Retry: "+IntegerToString(i,0),"/"+IntegerToString(retries));
        Alert(instrument," , ",order_comment,": An order was attempted but it did not succeed. Check the Journal tab of the Navigator window for errors.");
      }
      Sleep(sleep);
     }
   return ticket;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// Checking and moving trailing stop while the order is open
bool trailingstop_check_order(int ticket,int trail_pips,int threshold,int step)
  {
   if(ticket<=0) return true;
   if(!OrderSelect(ticket,SELECT_BY_TICKET)) return false;
   int digits=(int) MarketInfo(OrderSymbol(),MODE_DIGITS);
   double point=MarketInfo(OrderSymbol(),MODE_POINT);
   bool result=true;
   if(OrderType()==OP_BUY)
     {
      double new_moving_sl=OrderClosePrice()-(trail_pips*point); // the current price - the trail in pips
      double threshold_activation_price=OrderOpenPrice()+(threshold*point);
      double activation_sl=threshold_activation_price-(trail_pips*point);
      double step_in_pts=new_moving_sl-OrderStopLoss(); // keeping track of the distance between the potential stoploss and the current stoploss
      if(OrderStopLoss()==0|| compare_doubles(activation_sl,OrderStopLoss(),digits)==1)
        {
         if(compare_doubles(OrderClosePrice(),threshold_activation_price,digits)>=0) // if price met the threshold, move the stoploss
            result=modify(ticket,activation_sl);
        }
      else if(compare_doubles(step_in_pts,step*point,digits)>=0) // if price met the step, move the stoploss
        {
         result=modify(ticket,new_moving_sl);
        }
     }
   else if(OrderType()==OP_SELL)
     {
      double new_moving_sl=OrderClosePrice()+(trail_pips*point);
      double threshold_activation_price=OrderOpenPrice()-(threshold*point);
      double activation_sl=threshold_activation_price+(trail_pips*point);
      double step_in_pts=OrderStopLoss()-new_moving_sl;
      if(OrderStopLoss()==0|| compare_doubles(activation_sl,OrderStopLoss(),digits)==-1)
        {
         if(compare_doubles(OrderClosePrice(),threshold_activation_price,digits)<=0)
            result=modify(ticket,activation_sl);
        }
      else if(compare_doubles(step_in_pts,step*point,digits)>=0)
        {
         result=modify(ticket,new_moving_sl);
        }
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void trailingstop_check_all_orders(int trail,int threshold,int step,int magic=-1)
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

int signal_compare(int current_signal,int added_signal,bool exit=false) 
  {
  // signals are evaluated two at a time and the result will be used to compared with other signals until all signals are compared
   if(current_signal==TRADE_SIGNAL_VOID)
      return current_signal;
   else if(current_signal==TRADE_SIGNAL_NEUTRAL)
      return added_signal;
   else
     {
      if(added_signal==TRADE_SIGNAL_NEUTRAL)
         return current_signal;
      else if(added_signal==TRADE_SIGNAL_VOID)
         return added_signal;
      else if(added_signal!=current_signal)
        {
         if(exit)
            return TRADE_SIGNAL_VOID;
         else
            return TRADE_SIGNAL_NEUTRAL;
        }
     }
   return added_signal;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

double mm(MM method,string instrument,double lots,double sl_pips,double risk_mm1_percent,double lots_mm2,double per_mm2,double risk_mm3,double risk_mm4)
  {
   double balance=AccountBalance();
   double tick_value=MarketInfo(instrument,MODE_TICKVALUE);
   
   switch(method)
     {
      case MM_RISK_PERCENT:
         if(sl_pips>0) lots=((balance*risk_mm1_percent)/sl_pips)/tick_value;
         break;
      case MM_FIXED_RATIO:
         lots=balance*lots_mm2/per_mm2;
         break;
      case MM_FIXED_RISK:
         if(sl_pips>0) lots=(risk_mm3/tick_value)/sl_pips;
         break;
      case MM_FIXED_RISK_PER_POINT:
         lots=risk_mm4/tick_value;
         break;
     }
   // get information from the broker and then Normalize the lots double
   double min_lot=MarketInfo(instrument,MODE_MINLOT);
   double max_lot=MarketInfo(instrument,MODE_MAXLOT);
   int lot_digits=(int) -MathLog10(MarketInfo(instrument,MODE_LOTSTEP)); // MathLog10 returns the logarithm of a number (in this case, the MODE_LOTSTEP) base 10. So, this finds out how many digits in the lot the broker accepts.
   lots=NormalizeDouble(lots,lot_digits);
   // If the lots value is below or above the broker's MODE_MINLOT or MODE_MAXLOT, the lots will be change to one of those lot sizes. This is in order to prevent Error 131 - invalid trade volume error
   if(lots<min_lot) lots=min_lot;
   if(lots>max_lot) lots=max_lot;
   return lots;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

bool is_new_bar(string instrument,int timeframe,bool wait_for_next_bar=false)
  {
   static datetime bar_time=0;
   static double open_price=0;
   datetime current_bar_open_time=iTime(instrument,timeframe,0);
   double current_bar_open_price=iOpen(instrument,timeframe,0);
   int digits=(int)MarketInfo(instrument,MODE_DIGITS);  // TODO: why are the digits being converted to an int?
   if(bar_time==0 && open_price==0) // If it is the first time the function is called or it is the start of a new bar. This could be after the open time (aka in the middle) of a bar.
     {
      bar_time=current_bar_open_time; // update the time to the current time
      open_price=current_bar_open_price; // update the price to the current price
      if(wait_for_next_bar) // after loading the EA for the first time, if the user wants to wait for the next bar for the bar to be considered new
         return false;
      else return true;
     }
   else if(current_bar_open_time>bar_time && compare_doubles(open_price,current_bar_open_price,digits)!=0) // determine if the opening time and price of this bar is different than the previous one
        {
         bar_time=current_bar_open_time; // update the time to the current time
         open_price=current_bar_open_price; // update the price to the current price
         return true;
        }
      return false; // if it is not a new bar
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// This function solves the problem of an EA on a chart thinking it controls other EAs orders.
int count_orders(ENUM_ORDER_SET type=-1,int magic=-1,int pool=MODE_TRADES) // With pool, you can define whether to count current orders (MODE_TRADES) or closed and cancelled orders (MODE_HISTORY).
  {
   int count=0;
   for(int i=OrdersTotal();i>=0;i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,pool))
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

bool in_time_range(datetime time,int start_hour,int start_min,int end_hour,int end_min,int gmt_offset=0)
  {
   if(gmt_offset!=0) 
     {
      start_hour+=gmt_offset;
      end_hour+=gmt_offset;
     }
// Since a non-zero gmt_offset will make the start and end hour go beyond acceptable paremeters (below 0 or above 23), change the start_hour and end_hour to military time.
   if(start_hour>23) start_hour=(start_hour-23)-1;
   else if(start_hour<0) start_hour=23+start_hour+1;
   if(end_hour>23) end_hour=(end_hour-23)-1;
   else if(end_hour<0) end_hour=23+end_hour+1;
   
   int hour=TimeHour(time);
   int minute=TimeMinute(time);
   int current_time=(hour*3600)+(minute*60);
   int start_time=(start_hour*3600)+(start_min*60);
   int end_time=(end_hour*3600)+(end_min*60);
   
   if(start_time==end_time) // making sure that the start_time is classified as in the range
      return true;
   else if(start_time<end_time) // for the case when the user sets the start time to be less than the end time
     {
      if(current_time>=start_time && current_time<end_time) // if the current time is in the range
         return true;
     }
   else if(start_time>end_time) // for the case when the user sets the end time to be greater than the start time. This occurs when the start and end time are not the same day.
     {
      if(current_time>=start_time || current_time<end_time) // if the current time is in the range
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
      double virtual_stoploss=OrderOpenPrice()-(sl*point);
      double virtual_takeprofit=OrderOpenPrice()+(tp*point);
      if((sl>0 && compare_doubles(OrderClosePrice(),virtual_stoploss,digits)<=0) || 
         (tp>0 && compare_doubles(OrderClosePrice(),virtual_takeprofit,digits)>=0))
        {
         result=exit_order(ticket);
        }
     }
   else if(OrderType()==OP_SELL)
     {
      double virtual_stoploss=OrderOpenPrice()+(sl*point);
      double virtual_takeprofit=OrderOpenPrice()-(tp*point);
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

// use this function  in case you do not want the broker to know where your stop is
void virtualstop_check_all_orders(int sl,int tp,int magic=-1)
  {
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS))
         if(magic==-1 || magic==OrderMagicNumber())
            virtualstop_check_order(OrderTicket(),sl,tp);
     }
  }
  
//+------------------------------------------------------------------+