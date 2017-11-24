//+------------------------------------------------------------------+
//|                                            Relativity_EA_V01.mq4 |
//|                                                 Quant FX Capital |
//|                                   https://www.quantfxcapital.com |
//+------------------------------------------------------------------+
#property copyright "Quant FX Capital"
#property link      "https://www.quantfxcapital.com"
#property version   "1.01"
#property strict
//#property show_inputs // This can only be used for scripts. I added this because, by default, it will not show any external inputs. This is to override this behaviour so it deliberately shows the inputs.
// TODO: When strategy testing, make sure you have all the M5, D1, and W1 data because it is reference in the code.
// TODO: Always use NormalizeDouble() when computing the price (or lots or ADR?) yourself. This is not necessary for internal functions like OrderOPenPrice(), OrderStopLess(),OrderClosePrice(),Bid,Ask
// TODO: User the compare_doubles() function to compare two doubles.
// Remember: It has to be for a broker that will give you D1 data for at least around 6 months in order to calculate the Average Daily Range (ADR).
// Rmember: This EA calls the OrdersHistoryTotal() function which counts the ordres of the "Account History" tab of the terminal. Set the history there to 3 days.

enum ENUM_SIGNAL_SET
  {
   SIGNAL_SET_NONE=0,
   SIGNAL_SET_1=1,
   SIGNAL_SET_2=2
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum ENUM_DIRECTIONAL_MODE
  {
   BUYING_MODE=0,
   SELLING_MODE=1
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum ENUM_WHICH_RANGE
  {
   HIGH_MINUS_LOW=0,
   OPEN_MINUS_CLOSE_ABSOLUTE=1
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum ENUM_TRADE_SIGNAL  // since ENUM_ORDER_TYPE is not enough, this enum was created to be able to use neutral and void signals
  {
   TRADE_SIGNAL_VOID=-1, // exit all trades
   TRADE_SIGNAL_NEUTRAL=0, // no direction is determined. This happens when buy and sell signals are compared with each other.
   TRADE_SIGNAL_BUY,
   TRADE_SIGNAL_SELL
   
   // TODO: should you create TRADE_SIGNAL_SIT_ON_HANDS that will override all other buy and sell signals? (but not the void one)
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
   ORDER_SET_PENDING,
   ORDER_SET_SHORT_LONG_LIMIT_MARKET
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum ENUM_MM // Money Management
  {
   MM_RISK_PERCENT_PER_ADR, // 0 by default
   MM_RISK_PERCENT,
   MM_FIXED_RATIO,
   MM_FIXED_RISK,
   MM_FIXED_RISK_PER_POINT,
   MM_FIXED_LOT
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// general settings
	int charts_timeframe=PERIOD_M5;
	string symbol=NULL;
  static int EA_1_magic_num; // An EA can only have one magic number. Used to identify the EA that is managing the order. TODO: see if it can auto generate the magic number every time the EA is loaded on the chart.
  static bool uptrend_triggered=true;
  static bool downtrend_triggered=true;
   
// virtual stoploss variables
	int virtual_sl=0; // TODO: Change to a percent of ADR
	int virtual_tp=0; // TODO: Change to a percent of ADR
	
// breakeven variables
	int breakeven_threshold=500; // TODO: Change this to a percent of ADR. The percent of ADR in profit before setting the stop to breakeven.
	int breakeven_plus=0; // plus allows you to move the stoploss +/- from the entry price where 0 is breakeven, <0 loss zone, and >0 profit zone
	
// trailing stop variables
	int trail_value=20; // TODO: Change to a percent of ADR
	int trail_threshold=500; // TODO: Change to a percent of ADR
	int trail_step=20; // the minimum difference between the proposed new value of the stoploss to the current stoploss price // TODO: Change to a percent of ADR
	
	input bool only_enter_on_new_bar=false; // Should you only enter trades when a new bar begins?
	input bool wait_next_bar_on_load=false; // This setting currently affects all bars (including D1) so do not set it to true unless code changes are made. // When you load the EA, should it wait for the next bar to load before giving the EA the ability to enter a trade or calculate ADR?
	input bool exit_opposite_signal=true; // Should the EA exit trades when there is a signal in the opposite direction?
  bool long_allowed=true; // Are long trades allowed?
	bool short_allowed=true; // Are short trades allowed?
	
	input int max_num_EAs_at_once=28;
	input int max_directional_trades_at_once=1; // How many trades can the EA enter at the same time in the one direction on the current chart? (If 1, a long and short trade (2 trades) can be opened at the same time.)input int max_num_EAs_at_once=28; // What is the maximum number of EAs you will run on the same instance of a platform at the same time?
	input int max_trades_within_x_hours=1; // 0-x days (x depends on the setting of the Account History tab of the terminal). // How many trades are allowed to be opened (even if they are closed now) within the last x_hours?
	input int x_hours=3;
	input int max_directional_trades_each_day=1; // How many trades are allowed to be opened (even if they are close now) after the start of each current day?
	
// time filters - only allow EA to enter trades between a range of time in a day
	input int start_time_hour=0; // eligible time to start a trade. 0-23
	input int start_time_minute=30; // 0-59
	input int end_time_hour=23; // banned time to start a trade. 0-23
	input int end_time_minute=0; // 0-59
  input int exit_time_hour=23; // the exit_time should be before the trading range start_time and after trading range end_time
  input int exit_time_minute=30; // 0-59
	input int gmt_hour_offset=-3; // -3 if using Gain Capital. The value of 0 refers to the time zone used by the broker (seen as 0:00 on the chart). Adjust this offset hour value if the broker's 0:00 server time is not equal to when the time the NY session ends their trading day.
   
// enter_order
  input ENUM_SIGNAL_SET SIGNAL_SET=SIGNAL_SET_1; // Which signal set would you like to test? (the details of each signal set are found in the signal_entry function)
  // TODO: make sure you have coded for the scenerios when each of these is set to 0
	input double takeprofit_percent=0.3; // Must be a positive number. // TODO: Change to a percent of ADR (What % of ADR should you tarket?)
  input double stoploss_percent=1.0; // Must be a positive number.
	input double pullback_percent=-0.50; //  If you want a buy or sell limit order, it must be negative.
	input double max_spread_percent=.04; // Must be positive. What percent of ADR should the spread be less than? (Only for immediate orders and not pending.)
	
	input int entering_max_slippage=5; // Must be in whole number.
//input int unfavorable_slippage=5;
	string order_comment="Relativity EA"; // TODO: Add the parameter settings for the order to the message. // allows the robot to enter a description for the order. An empty string is a default value
//exit_order
	input int exiting_max_slippage=50; // Must be in whole number.
	
	input int active_order_expire=16; // How many hours can a trade be on that hasn't hit stoploss or takeprofit?
	input int pending_order_expire=// In how many seconds do you want your pending orders to expire?
	   /*Minutes=**/120
	   *
	   /*Seconds in a minute=*/60; 
	input bool market_exec=false; // False means that it is instant execution rather than market execution. Not all brokers offer market execution. The rule of thumb is to never set it as instant execution if the broker only provides market execution.
	color arrow_color_short=clrRed;
	color arrow_color_long=clrGreen;
	
//calculate_lots/mm variables
	ENUM_MM money_management=MM_RISK_PERCENT_PER_ADR;
	double risk_percent_per_ADR=0.02; // percent risked when using the MM_RISK_PER_ADR_PERCENT money management calculations. Note: This is not the percent of your balance you will be risking.
	double mm1_risk_percent=0.02; // percent risked when using the MM_RISK_PERCENT money management calculations
   // these variables will not be used with the MM_RISK_PERCENT money management strategy
	double lot_size=0.1;
	double mm2_lots=0.1;
	double mm2_per=1000;
	double mm3_risk=50;
	double mm4_risk=50;

// Market Trends
  input int H1s_to_roll=3; // How many hours should you roll to determine a short term market trend? (You are only allowed to input values divisible by 0.5.)
  input double max_weekend_gap_percent=.1; // What is the maximum weekend gap (as a percent of ADR) for H1s_to_roll to not take the previous week into account?
  input bool include_last_week=true; // Should the EA take Friday's moves into account when starting to determine length of the current move?
  static int ADR_pips; // TODO: make sure this maintains the value that was generated OnInit()
   
// ADR()
  input int num_ADR_months=2; // How months back should you use to calculate the average ADR? (Divisible by 1) TODO: this is not implemented yet.
  input double change_ADR_percent=-.25; // this can be a 0, negative, or positive decimal or whole number. 
// TODO: make sure you have coded for the scenerios when each of these is set to 0
  input double above_ADR_outlier_percent=1.5; // Can be any decimal with two numbers after the decimal point or a whole number. // How much should the ADR be surpassed in a day for it to be neglected from the average calculation?
  input double below_ADR_outlier_percent=.5; // Can be any decimal with two numbers after the decimal point or a whole number. // How much should the ADR be under in a day for it to be neglected from the average calculation?

bool all_user_input_variables_valid() // TODO: Work on this
  {
    return true;
  }
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
// Runs once when the EA is turned on
int OnInit()
  {
   return OnInit_Relativity_EA_1(SIGNAL_SET);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit_Relativity_EA_1(ENUM_SIGNAL_SET signal_set)
  {
    EA_1_magic_num=generate_magic_num(signal_set);
    bool input_variables_valid=all_user_input_variables_valid();
    
    int range_start_time=(start_time_hour*3600)+(start_time_minute*60);
    int range_end_time=(end_time_hour*3600)+(end_time_minute*60);
    int exit_time=(exit_time_hour*3600)+(exit_time_minute*60);
   
   // Print("The EA will not work properly. The input variables max_trades_in_direction, max_num_EAs_at_once, and max_trades_within_x_hours can't be 0 or negative.");
   
  if(exit_time>range_start_time && exit_time<range_end_time && !input_variables_valid)
    {
      Alert("Make sure that the trade exit_time_hour and exit_time_minute combination does not fall within the trading range start and end times or else there will be trouble!");
      return(INIT_FAILED);
    }
  else if(EA_1_magic_num<=0)
    {
      Alert("There is not a valid magic number for the Expert Advisor (EA). Without one, the EA will not run correctly. Get a MQL4 programmer check the code to find out why.");
      return(INIT_FAILED);
    }
  else if(!input_variables_valid)
    {
      Alert("One or more of the user input variables are not valid. The EA will not run correctly.");
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
//--- The first way to get the uninitialization reason code
   Print(__FUNCTION__,"_Uninitalization reason code = ",reason);
/*
//The second way to get the uninitialization reason code
   Print(__FUNCTION__,"_UninitReason = ",getUninitReasonText(_UninitReason));
*/
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string getUninitReasonText(int reasonCode)
  {
   string text="";

   switch(reasonCode)
     {
      case REASON_ACCOUNT:
         text="The account was changed";break;
      case REASON_CHARTCHANGE:
         text="The symbol or timeframe was changed";break;
      case REASON_CHARTCLOSE:
         text="The chart was closed";break;
      case REASON_PARAMETERS:
         text="The input-parameter was changed";break;
      case REASON_RECOMPILE: 
         text="The program "+__FILE__+" was recompiled";break;
      case REASON_REMOVE:
         text="Program "+__FILE__+" was removed from chart";break;
      case REASON_TEMPLATE:
         text="A new template was applied to chart";break;
      default:text="A different reason";
     }

   return text; 
  } 
//+------------------------------------------------------------------+
//| Expert testing function (not required)                           |
//+------------------------------------------------------------------+
/*double OnTester()
  {
    return 0;
  }*/
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
// Runs on every tick
void OnTick()
  {
   Relativity_EA_1(EA_1_magic_num);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Relativity_EA_1(int magic)
  {
   static bool ready=false, in_time_range=false;
   bool is_new_M5_bar=is_new_bar(symbol,PERIOD_M5,wait_next_bar_on_load);
   datetime current_time=TimeCurrent();
   int exit_signal=TRADE_SIGNAL_NEUTRAL, exit_signal_2=TRADE_SIGNAL_NEUTRAL; // 0
   int _exiting_max_slippage=exiting_max_slippage;
   
   exit_signal=signal_exit(SIGNAL_SET); // The exit signal should be made the priority and doesn't require in_time_range or adr_generated to be true

   if(exit_signal==TRADE_SIGNAL_VOID)       exit_all_trades_set(ORDER_SET_ALL,magic,_exiting_max_slippage); // close all pending and orders for the specific EA's orders. Don't do validation to see if there is an EA_magic_num because the EA should try to exit even if for some reason there is none.
   else if(exit_signal==TRADE_SIGNAL_BUY)   exit_all_trades_set(ORDER_SET_SHORT,magic,_exiting_max_slippage);
   else if(exit_signal==TRADE_SIGNAL_SELL)  exit_all_trades_set(ORDER_SET_LONG,magic,_exiting_max_slippage);

   // Breakeven (comment out if this functionality is not required)
   //if(breakeven_threshold>0) breakeven_check_all_orders(breakeven_threshold,breakeven_plus,order_magic);
   
   // Trailing Stop (comment out of this functionality is not required)
   //if(trail_value>0) trailingstop_check_all_orders(trail_value,trail_threshold,trail_step,order_magic);
   //   virtualstop_check(virtual_sl,virtual_tp); 

   if(is_new_M5_bar) // only check if it is in the time range once the EA is loaded and, then, afterward at the beginning of every M5 bar
     {
      exit_all_trades_set(ORDER_SET_MARKET,magic,_exiting_max_slippage,active_order_expire*3600,current_time); // This runs every 5 minutes (whether the time is in_time_range or not). It only exit trades that have been on for too long and haven't hit stoploss or takeprofit.
      in_time_range=in_time_range(current_time,start_time_hour,start_time_minute,end_time_hour,end_time_minute,gmt_hour_offset);

      if(in_time_range && !ready) 
        {
         ADR_pips=get_ADR(H1s_to_roll,below_ADR_outlier_percent,above_ADR_outlier_percent,change_ADR_percent);
         if(ADR_pips>0 && magic>0) 
           {
            ready=true; // the ADR that has just been calculated won't generate again until after the cycle of not being in the time range completes
            uptrend_triggered=false;
            downtrend_triggered=false;
           }
         else 
           {
            ready=false;
            uptrend_triggered=true;
            downtrend_triggered=true;
            return;
           }
        }
     }
   if(in_time_range && ready)
     {
      int enter_signal=TRADE_SIGNAL_NEUTRAL; // 0
   
      enter_signal=signal_pullback_after_ADR_triggered(); // this is the first signal and will apply to all signal sets so it gets run first
      enter_signal=signal_compare(enter_signal,signal_entry(SIGNAL_SET),false); // The entry signal requires in_time_range, adr_generated, and EA_magic_num>0 to be true.      

      if(enter_signal>0)
        {
         int days_seconds=(int)(current_time-(iTime(symbol,PERIOD_D1,0))+(gmt_hour_offset*3600)); // i am assuming it is okay to typecast a datetime (iTime) into an int since datetime is count of the number of seconds since 1970
         //int efficient_end_index=MathMin((MathMax(max_trades_within_x_hours*x_hours,max_directional_trades_each_day*24)*max_directional_trades_at_once*max_num_EAs_at_once-1),OrdersHistoryTotal()-1); // calculating the maximum orders that could have been placed so at least the program doesn't have to iterate through all orders in history (which can slow down the EA)
         
         if(enter_signal==TRADE_SIGNAL_BUY)
           {
            ENUM_ORDER_SET order_set=ORDER_SET_LONG;
            ENUM_ORDER_SET order_set2=ORDER_SET_SHORT_LONG_LIMIT_MARKET;
            
            if(exit_opposite_signal) exit_all_trades_set(ORDER_SET_SELL,magic,_exiting_max_slippage);
            int opened_today_count=count_orders (order_set, // should be first because the days_seconds variable was just calculated
                                                 magic,
                                                 MODE_HISTORY,
                                                 OrdersHistoryTotal()-1,
                                                 days_seconds,
                                                 current_time);
            int opened_recently_count=count_orders(order_set2,
                                                 magic,
                                                 MODE_HISTORY,
                                                 OrdersHistoryTotal()-1,
                                                 x_hours*3600,
                                                 current_time);
            int current_long_count=count_orders (order_set, // should be last because the harder ones should go first
                                                 magic,
                                                 MODE_TRADES,
                                                 OrdersTotal()-1,
                                                 0,
                                                 current_time); // counts all long (active and pending) orders for the current EA
            
            if(current_long_count<max_directional_trades_at_once &&  // just long
               opened_recently_count<max_trades_within_x_hours &&    // long and short
               opened_today_count<max_directional_trades_each_day)   // just long
              {
               if(!only_enter_on_new_bar || 
                  (only_enter_on_new_bar && is_new_M5_bar))
                     try_to_enter_order(OP_BUY,magic,entering_max_slippage);
              }
           }
         else if(enter_signal==TRADE_SIGNAL_SELL)
           {
            ENUM_ORDER_SET order_set=ORDER_SET_SHORT;
            ENUM_ORDER_SET order_set2=ORDER_SET_SHORT_LONG_LIMIT_MARKET;
            
            if(exit_opposite_signal) exit_all_trades_set(ORDER_SET_BUY,magic,_exiting_max_slippage);
            int opened_today_count=count_orders (order_set, // should be first because the days_seconds variable was just calculated
                                                 magic,
                                                 MODE_HISTORY,
                                                 OrdersHistoryTotal()-1,
                                                 days_seconds,
                                                 current_time);
            int opened_recently_count=count_orders(order_set2,
                                                 magic,
                                                 MODE_HISTORY,
                                                 OrdersHistoryTotal()-1,
                                                 x_hours*3600,
                                                 current_time);
            int current_short_count=count_orders(order_set, // should be last because the harder ones should go first
                                                 magic,
                                                 MODE_TRADES,
                                                 OrdersTotal()-1,
                                                 0,
                                                 current_time); // counts all short (active and pending) orders for the current EA
            
            if(current_short_count<max_directional_trades_at_once && // just short
               opened_recently_count<max_trades_within_x_hours &&    // short and long
               opened_today_count<max_directional_trades_each_day)   // just short
              {
               if(!only_enter_on_new_bar || 
                  (only_enter_on_new_bar && is_new_M5_bar))
                     try_to_enter_order(OP_SELL,magic,entering_max_slippage);
              }
           }
        }    
     }
    else
     {
       ready=false; // this makes sure to set it to false so when the time is within the time range again, the ADR can get generated
       uptrend_triggered=true; // 
       downtrend_triggered=true; // 
       bool time_to_exit=time_to_exit(current_time,exit_time_hour,exit_time_minute,gmt_hour_offset);
       if(time_to_exit) exit_all_trades_set(ORDER_SET_ALL,magic,_exiting_max_slippage); // this is the special case where you can exit open and pending trades based on a specified time (this should have been set to be outside of the trading time range)
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool over_extended_trend(ENUM_DIRECTIONAL_MODE mode,ENUM_WHICH_RANGE range_mode, double days_range_percent_threshold,int days_to_check,int num_to_be_true) // TODO: test if this works with a Script
  {
    bool answer=false;
    int uptrend_count=0, downtrend_count=0;
    double previous_days_close=-1;
    int digits=(int)MarketInfo(symbol,MODE_DIGITS);
    double ADR_points_threshold=NormalizeDouble((ADR_pips*Point)*days_range_percent_threshold,digits);
    double bid_price=Bid;
    
    if(mode==BUYING_MODE)
      {
        for(int i=days_to_check-1;i>=0;i++) // days_to_check should be past days to check + today
          {
            double days_range=0;
            
            if(range_mode==HIGH_MINUS_LOW)
              {
                if(i!=0) days_range=iHigh(symbol,PERIOD_D1,i)-iLow(symbol,PERIOD_D1,i);
                else days_range=bid_price-iLow(symbol,PERIOD_D1,i);
              }
            else if(range_mode==OPEN_MINUS_CLOSE_ABSOLUTE)
              {
                if(i!=0) days_range=iClose(symbol,PERIOD_D1,i)-iOpen(symbol,PERIOD_D1,i);
                else days_range=bid_price-iOpen(symbol,PERIOD_D1,i); // can be negative
              }
            if(days_range>=ADR_points_threshold) // only positive day_ranges pass this point
              { 
                if(i==days_to_check-1) // the first day is always counted as 1
                  {
                    uptrend_count++;
                    downtrend_count++;
                    break;
                  }

                double close_price=iClose(symbol,PERIOD_D1,i);
                previous_days_close=iClose(symbol,PERIOD_D1,i+1); 
      
                if(close_price>previous_days_close) 
                  {
                    uptrend_count++;
                    break;
                  }
              }
          }
        if(uptrend_count>=num_to_be_true) return !answer;
        else return answer;
      }
    else if(mode==SELLING_MODE)
      {
        for(int i=days_to_check-1;i>=0;i++) // days_to_check should be past days to check + today
          {
            double days_range=0;
            
            if(range_mode==HIGH_MINUS_LOW) 
              {
                if(i!=0) days_range=iHigh(symbol,PERIOD_D1,i)-iLow(symbol,PERIOD_D1,i);
                else days_range=iHigh(symbol,PERIOD_D1,i)-bid_price;
              }
            else if(range_mode==OPEN_MINUS_CLOSE_ABSOLUTE)
              {
                if(i!=0) days_range=iOpen(symbol,PERIOD_D1,i)-iClose(symbol,PERIOD_D1,i);
                else days_range=iOpen(symbol,PERIOD_D1,i)-bid_price;
              }
            if(days_range>=ADR_points_threshold) // only positive day_ranges pass this point
              { 
                if(i==days_to_check-1) // the first day is always counted as 1
                  {
                    uptrend_count++;
                    downtrend_count++;
                    break;
                  }
                  
                double close_price=iClose(symbol,PERIOD_D1,i);
                previous_days_close=iClose(symbol,PERIOD_D1,i+1); 
      
                if(close_price<previous_days_close)
                  {
                    downtrend_count++;
                    break;                  
                  }
              }
          }
        if(downtrend_count>=num_to_be_true) return !answer;
        else return answer;
      }
    return answer;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int signal_pullback_after_ADR_triggered()
  {
    int signal=TRADE_SIGNAL_NEUTRAL;
    
    if(!uptrend_triggered)
      {
        if(uptrend_ADR_threshold_price_met(true)>0)
          {
            return signal=TRADE_SIGNAL_BUY;
          }
      }
   // for a buying signal, take the level that adr was triggered and subtract the pullback_pips to get the pullback_entry_price
   // if the pullback_entry_price is met or exceeded, signal = TRADE_SIGNAL_BUY
    if(!downtrend_triggered)
      {
      if(downtrend_ADR_threshold_price_met(true)>0) 
        {
          return signal=TRADE_SIGNAL_SELL;
        }
      }
    return signal;
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Checks for the entry of orders
int signal_entry(ENUM_SIGNAL_SET signal_set) // gets called for every tick
  {
   int signal=TRADE_SIGNAL_NEUTRAL;
   
/* Add 1 or more entry signals below. 
   With more than 1 signal, you would follow this code using the signal_compare function. 
   "signal=signal_compare(signal,signal_pullback_after_ADR_triggered());"
   As each signal is compared with the previous signal, the signal variable will change and then the final signal wil get returned.
*/
   if(signal_set==SIGNAL_SET_1)
     {
      signal=signal_compare(signal,signal_x_consecutive_directional_days(),false);
      return signal;
     }
   if(signal_set==SIGNAL_SET_2)
     {
      return signal;
     }
   else return TRADE_SIGNAL_NEUTRAL;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Checks for the exit of orders
int signal_exit(ENUM_SIGNAL_SET signal_set)
  {
   int signal=TRADE_SIGNAL_NEUTRAL;
/* Add 1 or more entry signals below. 
   With more than 1 signal, you would follow this code using the signal_compare function. 
   "signal=signal_compare(signal,signal_pullback_after_ADR_triggered());"
   As each signal is compared with the previous signal, the signal variable will change and then the final signal wil get returned.
*/ 
// The 3rd argument of the signal_compare function should explicitely be set to "true" every time.

   if(signal_set==SIGNAL_SET_1)
     {
      return signal;
     }
   if(signal_set==SIGNAL_SET_2)
     {
      return signal;
     }
   else return signal;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int signal_compare(int current_signal,int added_signal,bool exit_when_buy_and_sell=false) 
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
      // at this point, the only two options left are if they are both buy, both sell, or buy and sell
      else if(added_signal!=current_signal) // if one signal is a buy signal and the other sign
        {
         if(exit_when_buy_and_sell) return TRADE_SIGNAL_VOID;
         else return TRADE_SIGNAL_NEUTRAL;
        }
     }
   return added_signal;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
int generate_magic_num(ENUM_SIGNAL_SET)
  {
     /*int total_variable_count=10;
     string symbols_string=symbol;
     string unique_string="";
     int magic_int=0; // This has to be initialized to 0. Do not change this unless you analyze and make changes to all the code that depends on this function because if -1 ever gets returned that means to close all orders from all EAs!
     double input_variables[10]; // only allowed to put constants in the array
     
     // add all the double and int global input variables to the input_variables array which will allow the magic_int to be unique based upon how the user sets them
     
     
  
    
    
    // int max and min values https://docs.mql4.com/basis/types/integer
    
    
    
    
    
     int symbols_int=StrToInteger(symbols_string);
     string symbol_num_string=IntegerToString(symbols_int);
  
     for(int i=0;i<total_variable_count;i++)
       {
       // get the "i"th global input variables from the input_variable
  
        double another_variable=input_variables[i];
        
        if(MathIsValidNumber(another_variable))
          {
           if(MathMod(another_variable,1)!=0) // if it is NOT a whole number
             {
              another_variable=NormalizeDouble(another_variable,2)*100; // TODO: does NormalizeDouble make it so doubles only have two numbers after the decimal point?
             }
             
           // now any number that gets to this point can be converted into an int without any loss of data
           int another_variable_int=(int)another_variable;
           string num_string=IntegerToString(another_variable_int);
           
           if(another_variable_int>0) unique_string=StringConcatenate("1",num_string); // create a unique string for this specific positive number
           else if(another_variable_int!=NULL) unique_string=StringConcatenate("0",num_string); // create a unique string for this specific negative number 
          }
        else // it must be a string or some other unknown type
          {
           Alert("A non-valid number was used to try to make the magic number. Only numbers are allowed. The EA cannot go forward until the Expert Advisor MQL4 programmer fixes the code.");
          }
       }
     string magic_string=StringConcatenate(symbol_num_string,unique_string);
     magic_int=StrToInteger(magic_string);
     return magic_int;
  /*
  // started work on a different option if the one above does not work out.
     MathSrand(1);
     int large_random_num=MathRand()*MathRand();
     
     while(magic_num_in_use(large_random_num))
     {
       large_random_num=MathRand()*MathRand(); // from 1 through 1,073,676,289
     }
     return large_random_num;
     
   */
   
   return 1;
   
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
bool is_new_bar(string instrument,int timeframe,bool wait_for_next_bar=false)
  {
   static datetime bar_time=0;
   static double open_price=0;
   datetime current_bar_open_time=iTime(instrument,timeframe,0);
   double current_bar_open_price=iOpen(instrument,timeframe,0);
   int digits=(int)MarketInfo(instrument,MODE_DIGITS);
   
   if(bar_time==0 && open_price==0) // If it is the first time the function is called or it is the start of a new bar. This could be after the open time (aka in the middle) of a bar.
     {
      bar_time=current_bar_open_time;
      open_price=current_bar_open_price;
      if(wait_for_next_bar) return false; // after loading the EA for the first time, if the user wants to wait for the next bar for the bar to be considered new
      else return true;
     }
   else if(current_bar_open_time>bar_time && compare_doubles(open_price,current_bar_open_price,digits)!=0) // if the opening time and price of this bar is different than the opening time and price of the previous one
     {
      bar_time=current_bar_open_time; // assuring the true value only gets returned for 1 tick and not the very next ones
      open_price=current_bar_open_price; // assuring the true value only gets returned for 1 tick and not the very next ones
      return true;
     }
   else return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
     
     int time_hour=TimeHour(current_time);
     int time_minute=TimeMinute(current_time);
     int exit_hour=hour*3600;
     int exit_min=min*60;
     
     if(time_hour==exit_hour && time_minute==exit_min) return true; // this will only give the signal to exit for every tick for 1 minute per day
     else return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int ADR_calculation(double low_outlier,double high_outlier,double change_ADR)
  {
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
           
           if(compare_doubles(ADR_ratio,low_outlier,2)==1 && compare_doubles(ADR_ratio,high_outlier,2)==-1) // filtering out outliers
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
           
           if(compare_doubles(ADR_ratio,low_outlier,2)==1 && compare_doubles(ADR_ratio,high_outlier,2)==-1) // filtering out outliers
             {
              x_mnth_non_sunday_ADR_sum+=days_range;
              x_mnth_non_sunday_count++;
             }
          }
       }
     // adr doesn't need to be Normalized because it has been converted into an int.
     int adr=(int)((x_mnth_non_sunday_ADR_sum/Point)/x_mnth_non_sunday_count); // converting it away from points to more human understandable numbers
     // int adr=.0080;
     if(change_ADR==0 || change_ADR==NULL) return adr;
     else return (int)((adr*change_ADR)+adr); // include the ability to increase\decrease the ADR by a certain percentage where the input is a global variable
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int get_ADR(int hours_to_roll,double low_outlier,double high_outlier,double change_ADR) // get the Average Daily Range
  {
    static int adr=0;
    int _num_ADR_months=num_ADR_months;
    bool is_new_D1_bar=is_new_bar(symbol,PERIOD_D1,false);
     
    if(low_outlier>high_outlier || _num_ADR_months<=0 || _num_ADR_months==NULL || MathMod(hours_to_roll,.5)!=0)
      {
        return -1; // if the user inputed the wrong outlier variables or a H1s_to_roll number that is not divisible by .5, it is not possible to calculate ADR
      }  
    if(adr==0 || is_new_D1_bar) // if it is the first time the function is called
      {
        int calculated_adr=ADR_calculation(low_outlier,high_outlier,change_ADR);
        adr=calculated_adr; // make the function remember the calculation the next time it is called
        return adr;
      }
    return adr; // if it is not the first time the function is called it is the middle of a bar, return the static adr
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+  
int get_moves_start_bar(int _H1s_to_roll,int gmt_offset,double _max_weekend_gap_percent,bool _include_last_week=true)
  {
   datetime week_start_open_time=iTime(symbol,PERIOD_W1,0)+(gmt_offset*3600); // The iTime of the week bar gives you the time that the week is 0:00 on the chart so I shifted the time to start when the markets actually start.
   int week_start_bar=iBarShift(symbol,PERIOD_M5,week_start_open_time,false);
   int move_start_bar=_H1s_to_roll*12;
  
   if(move_start_bar<=week_start_bar)
     {
      return move_start_bar;
     }
   else if(_include_last_week)
     {
      double weekend_gap_points=MathAbs(iClose(symbol,PERIOD_W1,1)-iOpen(symbol,PERIOD_W1,0));
      double max_weekend_gap_points=NormalizeDouble((ADR_pips*Point)*_max_weekend_gap_percent,Digits); // TODO: this may not need to be normalized
      
      if(weekend_gap_points>=max_weekend_gap_points) return week_start_bar;
      else return move_start_bar;
     }
   else
     {
      return week_start_bar;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double periods_pivot_price(ENUM_DIRECTIONAL_MODE mode)
  {
    if(mode==BUYING_MODE)
      return iLow(symbol,
                PERIOD_M5,
                iLowest(symbol,
                        PERIOD_M5,
                        MODE_LOW,
                        WHOLE_ARRAY,
                        get_moves_start_bar(H1s_to_roll,
                                            gmt_hour_offset,
                                            max_weekend_gap_percent,
                                            include_last_week))); // get the price of the bar that has the lowest price for the determined period
    else if(mode==SELLING_MODE) 
      return iHigh(symbol,
                 PERIOD_M5,
                 iHighest(symbol,
                          PERIOD_M5,
                          MODE_HIGH,
                          WHOLE_ARRAY,
                          get_moves_start_bar(H1s_to_roll,
                                              gmt_hour_offset,
                                              max_weekend_gap_percent,
                                              include_last_week))); // get the price of the bar that has the highest price for the determined period
    else 
      return -1;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double uptrend_ADR_threshold_price_met(bool get_current_bid_instead=false)
  {
   static double LOP=periods_pivot_price(BUYING_MODE);
   double point=MarketInfo(symbol,MODE_POINT);
   double pip_move_threshold=ADR_pips*point;
   double current_bid=Bid;
   
   if(LOP==-1) // this part is necessary in case periods_pivot_price ever returns 0
     {
       return -1;
     }
   else if(current_bid<LOP) // if the low of the range was surpassed
     {
       // since the bottom of the range was surpassed, you have to reset the LOP. You might as well take this opportunity to take the period into account.
       LOP=periods_pivot_price(BUYING_MODE);
       return -1;
     } 
   else if(current_bid-LOP>=pip_move_threshold) // if the pip move meets or exceed the ADR_Pips in points, return the current bid. Note: this will return true over and over again
     {
       // since the top of the range was surpassed and a pending order would be created, this is a good opportunity to update the LOP since you can't just leave it as the static value constantly
       LOP=periods_pivot_price(BUYING_MODE);
       if(current_bid-LOP>=pip_move_threshold) 
         if(get_current_bid_instead)
           {
            return current_bid; // TODO: should you return the current_bid or LOP+pip_move_threshold? // check if it is actually true by taking the new calculation of Low Of Period into account
           }
         else 
           {
            return LOP+pip_move_threshold;
           }
       else return -1;
     }         
   else return -1;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double downtrend_ADR_threshold_price_met(bool get_current_bid_instead=false)
  {
   static double HOP=periods_pivot_price(SELLING_MODE);
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
       HOP=periods_pivot_price(SELLING_MODE);
       return -1;
     } 
   else if(HOP-current_bid>=pip_move_threshold) // if the pip move meets or exceed the ADR_Pips in points, return the current bid. Note: this will return true over and over again
     {
       // since the top of the range was surpassed and a pending order would be created, this is a good opportunity to update the LOP since you can't just leave it as the static value constantly
       HOP=periods_pivot_price(SELLING_MODE);
       if(HOP-current_bid>=pip_move_threshold) 
         if(get_current_bid_instead)
           return current_bid; // TODO: should you return the current_bid or HOP-pip_move_threshold? // check if it is actually true by taking the new calculation of Low Of Period into account
           else return HOP-pip_move_threshold;
       else return -1;
     }         
   else return -1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool breakeven_check_order(int ticket,int threshold_pips,int plus_pips) 
  {
   if(ticket<=0) return true; // if it is a valid ticket, return true
   if(!OrderSelect(ticket,SELECT_BY_TICKET)) return false; // if there is no ticket, it cannot be process so return false
   int digits=(int)MarketInfo(OrderSymbol(),MODE_DIGITS); // how many digit broker
   double point=MarketInfo(OrderSymbol(),MODE_POINT); // get the point for the instrument
   bool result=true; // initialize the variable result
   double order_sl=OrderStopLoss();
   if(OrderType()==OP_BUY) // if it is a buy order
     {
      double new_sl=OrderOpenPrice()+(plus_pips*point); // calculate the price of the new stoploss
      double profit_in_pts=OrderClosePrice()-OrderOpenPrice(); // calculate how many points in profit the trade is in so far
      if(order_sl==0 || compare_doubles(new_sl,order_sl,digits)==1) // if there is no stoploss or the potential new stoploss is greater than the current stoploss
         if(compare_doubles(profit_in_pts,threshold_pips*point,digits)>=0) // if the profit in points so far > provided threshold, then set the order to breakeven
            result=modify(ticket,new_sl);
     }
   else if(OrderType()==OP_SELL)
     {
      double new_sl=OrderOpenPrice()-(plus_pips*point);
      double profit_in_pts=OrderOpenPrice()-OrderClosePrice();
      if(order_sl==0 || compare_doubles(new_sl,order_sl,digits)==-1)
         if(compare_doubles(profit_in_pts,threshold_pips*point,digits)>=0)
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
         if(entryPrice==-1) // it is -1 if there was not entryPrice sent to this function (the 4th parameter)
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
bool modify(int ticket,double sl,double tp=-1,double entryPrice=-1,datetime expire=0,color a_color=clrNONE,int retries=3,int sleep_milisec=500)
  {
   bool result=false;
   if(ticket>0)
     {
      for(int i=0;i<retries;i++)
        {
         if(!IsConnected()) Print("The EA can't modify ticket ",IntegerToString(ticket)," because there is no internet connection.");
         else if(!IsExpertEnabled()) Print("The EA can't modify ticket ",IntegerToString(ticket)," because EAs are not enabled in the trading platform.");
         else if(IsTradeContextBusy()) Print("The EA can't modify ticket ",IntegerToString(ticket)," because The trade context is busy.");
         else if(!IsTradeAllowed()) Print("The EA can't modify ticket ",IntegerToString(ticket)," because the trade is not allowed in the trading platform.");
         else result=modify_order(ticket,sl,tp,entryPrice,expire,a_color); // entryPrice could be -1 if there was no entryPrice sent to this function
         if(result)
            break;
         Sleep(sleep_milisec);
      // TODO: setup an email and SMS alert.
     Print(OrderSymbol()," , ",order_comment,", An order was attempted to be modified but it did not succeed. Last Error: (",IntegerToString(GetLastError(),0),"), Retry: ",IntegerToString(i,0),"/"+IntegerToString(retries));
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
bool exit_order(int ticket,int max_slippage,color a_color=clrNONE)
  {
   bool result=false;
   if(OrderSelect(ticket,SELECT_BY_TICKET))
     {
      if(OrderType()<=1) // if order type is an OP_BUY or OP_SELL (not a pending order). (OrderType() can be successfully called after a successful selection using OrderSelect())
        {
         result=OrderClose(ticket,OrderLots(),OrderClosePrice(),max_slippage,a_color); // current order
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
bool try_to_exit_order(int ticket,int max_slippage,color a_color=clrNONE,int retries=3,int sleep_milisec=500)
  {
   bool result=false;
   
   // TODO: you may want to calculate and add another argument (exiting_max_slippage) to the exit_order function
   for(int i=0;i<retries;i++)
     {
      if(!IsConnected()) Print("The EA can't close ticket ",IntegerToString(ticket)," because there is no internet connection.");
      else if(!IsExpertEnabled()) Print("The EA can't close ticket ",IntegerToString(ticket)," because EAs are not enabled in the trading platform.");
      else if(IsTradeContextBusy()) Print("The EA can't close ticket ",IntegerToString(ticket)," because the trade context is busy.");
      else if(!IsTradeAllowed()) Print("The EA can't close ticket ",IntegerToString(ticket)," because the close order is not allowed in the trading platform.");
      else result=exit_order(ticket,max_slippage,a_color);
      if(result)
         break;
      // TODO: setup an email and SMS alert.
      // Make sure to use OrderSymbol() instead of symbol to get the instrument of the order.
      Print("Closing order# ",DoubleToStr(OrderTicket(),0)," failed. Last Error: ",DoubleToStr(GetLastError(),0));
      Sleep(sleep_milisec);
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// TODO: Create a feature to exit_all at a specific time you have set as a extern variable
// By default, if the type and magic number is not supplied it is set to -1 so the function exits all orders (including ones from different EAs). But, there is an option to specify the type of orders when calling the function.
void exit_all(int type=-1,int magic=-1,int max_slippage=50) 
  {
   for(int i=OrdersTotal()-1;i>=0;i--) // it has to iterate through the array from the highest to lowest
     {
      if(OrderSelect(i,SELECT_BY_POS)) // if an open trade can be found
        {
         if((type==-1 || type==OrderType()) && (magic==-1 || magic==OrderMagicNumber()))
            try_to_exit_order(OrderTicket(),max_slippage);
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// This is similar to the exit_all function except that it allows you to choose more sets  to close. It will iterate through all open trades and close them based on the order type and magic number
void exit_all_trades_set(ENUM_ORDER_SET type_needed=ORDER_SET_ALL,int magic=-1,int max_slippage=50,int exit_seconds=0,datetime current_time=-1)  // magic==-1 means that all orders/trades will close (including ones managed by other running EAs)
  {
   for(int i=OrdersTotal()-1;i>=0;i--) // interate through the index from position 0 to OrdersTotal()-1
     {
      if(OrderSelect(i,SELECT_BY_POS)) // if an open trade can be found
        {
         if(magic==OrderMagicNumber() || magic==-1)
           {
            int actual_type=OrderType();
            int ticket=OrderTicket();
            
            if(exit_seconds>0 && current_time>0)
              if((current_time-OrderOpenTime())<exit_seconds) break;  // TODO: be sure that this still can get the open time of the current selected ticket
                
            switch(type_needed)
              {
               case ORDER_SET_BUY:
                  if(actual_type==OP_BUY) try_to_exit_order(ticket,max_slippage);
                  break;
               case ORDER_SET_SELL:
                  if(actual_type==OP_SELL) try_to_exit_order(ticket,max_slippage);
                  break;
               case ORDER_SET_BUY_LIMIT:
                  if(actual_type==OP_BUYLIMIT) try_to_exit_order(ticket,max_slippage);
                  break;
               case ORDER_SET_SELL_LIMIT:
                  if(actual_type==OP_SELLLIMIT) try_to_exit_order(ticket,max_slippage);
                  break;
               /*case ORDER_SET_BUY_STOP:
                  if(actual_type==OP_BUYSTOP) try_to_exit_order(ticket,max_slippage);
                  break;
               case ORDER_SET_SELL_STOP:
                  if(actual_type==OP_SELLSTOP) try_to_exit_order(ticket,max_slippage);
                  break;*/
               case ORDER_SET_LONG:
                  if(actual_type==OP_BUY || actual_type==OP_BUYLIMIT /*|| ordertype==OP_BUYSTOP*/)
                  try_to_exit_order(ticket,max_slippage);
                  break;
               case ORDER_SET_SHORT:
                  if(actual_type==OP_SELL || actual_type==OP_SELLLIMIT /*|| ordertype==OP_SELLSTOP*/)
                  try_to_exit_order(ticket,max_slippage);
                  break;
               case ORDER_SET_LIMIT:
                  if(actual_type==OP_BUYLIMIT || actual_type==OP_SELLLIMIT)
                  try_to_exit_order(ticket,max_slippage);
                  break;
               /*case ORDER_SET_STOP:
                  if(actual_type==OP_BUYSTOP || actual_type==OP_SELLSTOP)
                  try_to_exit_order(ticket,max_slippage);
                  break;*/
               case ORDER_SET_MARKET:
                  if(actual_type<=1) try_to_exit_order(ticket,max_slippage);
                  break;
               case ORDER_SET_PENDING:
                  if(actual_type>1) try_to_exit_order(ticket,max_slippage);
                  break;
               default: try_to_exit_order(ticket,max_slippage); // this is the case where type==ORDER_SET_ALL falls into
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool acceptable_spread(string instrument,bool refresh_rates,double _max_spread_percent)
{
   if(refresh_rates) RefreshRates();
   double spread=MarketInfo(instrument,MODE_SPREAD); // already normalized. I put this check here because the rates were just refereshed.
   if(compare_doubles(spread,(ADR_pips*_max_spread_percent)*Point,1)<=0) return true; // Keeps the EA from entering trades when the spread is too wide for market orders (but not pending orders). Note: It may never enter on exotic currencies (which is good automation).
   else return false;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void try_to_enter_order(ENUM_ORDER_TYPE type,int magic=0,int max_slippage=50)
  {
   double distance_pips;
   double periods_pivot_price;
   color arrow_color;
   double _pullback_percent=pullback_percent;
   
   if(_pullback_percent==0 || _pullback_percent==NULL) distance_pips=0;
   else distance_pips=NormalizeDouble(ADR_pips*_pullback_percent,2);
   
   if(type==OP_BUY /*|| type==OP_BUYSTOP || type==OP_BUYLIMIT*/) // what is the purpose of checking if it is a buystop or sellstop if the only type that gets sent to this function is OP_BUY?
     {
      if(!long_allowed) return;
      periods_pivot_price=periods_pivot_price(BUYING_MODE);
      arrow_color=arrow_color_long;
     }
   else if(type==OP_SELL /*|| type==OP_SELLSTOP || type==OP_SELLLIMIT*/)
     {
      if(!short_allowed) return;
      periods_pivot_price=periods_pivot_price(SELLING_MODE);
      arrow_color=arrow_color_short;
     }
   else return;
      
   double lots=calculate_lots(money_management,risk_percent_per_ADR);

   check_for_entry_errors(symbol,
               type,
               lots,
               distance_pips, // the distance_pips you are sending to the function should always be positive
               periods_pivot_price,
               NormalizeDouble(ADR_pips*stoploss_percent,2),
               NormalizeDouble(ADR_pips*takeprofit_percent,2),
               max_slippage,
               order_comment,
               magic,
               pending_order_expire,
               arrow_color,
               market_exec); 
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/*double calculate_entry_price()
   {
   }*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// the distanceFromCurrentPrice parameter is used to specify what type of order you would like to enter
int send_and_get_order_ticket(string instrument,int cmd,double lots,double distanceFromCurrentPrice,double periods_pivot_price,double sl_pips,double tp_pips,int max_slippage,string comment=NULL,int magic=0,int expire=0,color a_clr=clrNONE,bool market=false) // the "market" argument is to make this function compatible with brokers offering market execution. By default, it uses instant execution.
  {
   double entryPrice=0; 
   double price_sl=0, price_tp=0;
   double point=MarketInfo(instrument,MODE_POINT); // getting the value of 1 point for the instrument
   datetime expire_time=0; // 0 means there is no expiration time for a pending order
   int order_type=-1; // -1 means there is no order because actual orders are >=0
   // simplifying the arguments for the function by only allowing OP_BUY and OP_SELL and letting logic determine if it is a market or pending order based off the distanceFromCurrentPrice variable
   if(cmd==OP_BUY) // logic for long trades
     {
      bool instant_exec=!market;
      if(distanceFromCurrentPrice>0) order_type=OP_BUYLIMIT;
      else if(distanceFromCurrentPrice==0) order_type=OP_BUY;
      else /*if(distanceFromCurrentPrice>0) order_type=OP_BUYSTOP*/ return 0;
      if(order_type==OP_BUYLIMIT /*|| order_type==OP_BUYSTOP*/)
        {
         if(periods_pivot_price<0) return 0;
         entryPrice=(periods_pivot_price+(ADR_pips*point))-(distanceFromCurrentPrice*point); // setting the entryPrice this way prevents setting your limit and stop orders based on the current price (which would have caused inaccurate setting of prices)
        }
      else if(order_type==OP_BUY)
        {
         if(acceptable_spread(instrument,true,max_spread_percent)) entryPrice=MarketInfo(instrument,MODE_ASK);// Keeps the EA from entering trades when the spread is too wide for market orders (but not pending orders). Note: It may never enter on exotic currencies (which is good automation).
         // TODO: create an alert informing the user that the trade was not executed because of the spread being too wide
         else return 0;
        }
      if(instant_exec) // if the user wants instant execution (which the system allows them to input sl and tp prices)
        {
         if(sl_pips>0) price_sl=entryPrice-(sl_pips*point); // check if the stoploss and take profit prices can be determined
         if(tp_pips>0) price_tp=entryPrice+(tp_pips*point);
        }
     }
   else if(cmd==OP_SELL) // logic for short trades
     {
      bool instant_exec=!market;
      if(distanceFromCurrentPrice>0) order_type=OP_SELLLIMIT;
      else if(distanceFromCurrentPrice==0) order_type=OP_SELL;
      else /*if(distanceFromCurrentPrice<0) order_type=OP_SELLSTOP*/ return 0;
      if(order_type==OP_SELLLIMIT /*|| order_type==OP_SELLSTOP*/)
        {
         if(periods_pivot_price<0) return 0;
         entryPrice=(periods_pivot_price-(ADR_pips*point))+(distanceFromCurrentPrice*point); // setting the entryPrice this way prevents setting your limit and stop orders based on the current price (which would have caused inaccurate setting of prices)
        }
      else if(order_type==OP_SELL)
        {
         if(acceptable_spread(instrument,true,max_spread_percent)) entryPrice=MarketInfo(instrument,MODE_BID); // Keeps the EA from entering trades when the spread is too wide for market orders (but not pending orders). Note: It may never enter on exotic currencies (which is good automation).
         // TODO: create an alert informing the user that the trade was not executed because the spread was too wide         
         else return 0;
        }
      if(instant_exec) // if the user wants instant execution (which allows them to input the sl and tp prices)
        {
         if(sl_pips>0) price_sl=entryPrice+(sl_pips*point); // check if the stoploss and take profit prices can be determined
         if(tp_pips>0) price_tp=entryPrice-(tp_pips*point);
        }
     }
   if(order_type<0) return 0; // if there is no order
   else if(order_type==0 || order_type==1) expire_time=0; // if it is NOT a pending order, set the expire_time to 0 because it cannot have an expire_time
   else if(expire>0) // if the user wants pending orders to expire
   expire_time=(datetime)MarketInfo(instrument,MODE_TIME)+expire; // expiration of the order = current time + expire time
   if(market) // If the user wants market execution (which does NOT allow them to input the sl and tp prices), this will calculate the stoploss and takeprofit AFTER the order to buy or sell is sent.
     {
      int ticket=OrderSend(instrument,order_type,lots,entryPrice,max_slippage,0,0,comment,magic,expire_time,a_clr);
      if(ticket>0) // if there is a valid ticket
        {
         if(OrderSelect(ticket,SELECT_BY_TICKET))
           {
            if(cmd==OP_BUY)
              {
               if(sl_pips>0) price_sl=OrderOpenPrice()-(sl_pips*point);
               if(tp_pips>0) price_tp=OrderOpenPrice()+(tp_pips*point);
               uptrend_triggered=true;
               downtrend_triggered=false;
              }
            else if(cmd==OP_SELL)
              {
               if(sl_pips>0) price_sl=OrderOpenPrice()+(sl_pips*point);
               if(tp_pips>0) price_tp=OrderOpenPrice()-(tp_pips*point);
               uptrend_triggered=false;
               downtrend_triggered=true;
              }
            bool result=modify(ticket,price_sl,price_tp);
           }
        }
      return ticket;
     }
   int ticket=OrderSend(instrument,order_type,lots,entryPrice,max_slippage,price_sl,price_tp,comment,magic,expire_time,a_clr);
   if(ticket>0)
    {
      if(OrderSelect(ticket,SELECT_BY_TICKET))
        {
          if(cmd==OP_BUY)
            {
              uptrend_triggered=true;
              downtrend_triggered=false;
            }
          else if(cmd==OP_SELL)
            {
              uptrend_triggered=false;
              downtrend_triggered=true;
            }
        }
    }
   return ticket;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int check_for_entry_errors(string instrument,int cmd,double lots,double distanceFromCurrentPrice,double periods_pivot_price,double sl,double tp,int max_slippage,string comment=NULL,int magic=0,int expire=0,color a_clr=clrNONE,bool market=false,int retries=3,int sleep_milisec=500)
  {
   int ticket=0;
   for(int i=0;i<retries;i++)
     {
      if(IsStopped()) Print("The EA can't enter a trade because the EA was stopped.");
      else if(!IsConnected()) Print("The EA can't enter a trade because there is no internet connection.");
      else if(!IsExpertEnabled()) Print("The EA can't enter a trade because EAs are not enabled in trading platform.");
      else if(IsTradeContextBusy()) Print("The EA can't enter a trade because the trade context is busy.");
      else if(!IsTradeAllowed()) Print("The EA can't enter a trade because the trade is not allowed in the trading platform.");
      else ticket=send_and_get_order_ticket(instrument,cmd,lots,distanceFromCurrentPrice,periods_pivot_price,sl,tp,max_slippage,comment,magic,expire,a_clr,market);
      if(ticket>0) break;
      else
      { 
        // TODO: setup an email and SMS alert.
        Print(instrument," , ",order_comment,": An order was attempted but it did not succeed. If there are no errors here, market factors may not have met the code's requirements within the send_and_get_order_ticket function. Last Error:, (",IntegerToString(GetLastError(),0),"), Retry: "+IntegerToString(i,0),"/"+IntegerToString(retries));
        Alert(instrument," , ",order_comment,": An order was attempted but it did not succeed. Check the Journal tab of the Navigator window for errors.");
      }
      Sleep(sleep_milisec);
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
double calculate_lots(ENUM_MM _money_management,double _risk_percent_per_ADR=.02)
  {
    double pips=0;
    double _stoploss_percent=stoploss_percent;

    if(_money_management==MM_RISK_PERCENT_PER_ADR)
      pips=ADR_pips;
    else if(ADR_pips>0 && _stoploss_percent>0)
      pips=NormalizeDouble(ADR_pips*_stoploss_percent,2); // could be 0 if stoploss_percent is set to 0 
    else 
      pips=ADR_pips;

    double lots=get_lots(_money_management,
                        symbol,
                        lot_size,
                        _risk_percent_per_ADR,
                        pips,
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
double get_lots(ENUM_MM method,string instrument,double lots,double _risk_percent_per_ADR,double pips,double risk_mm1_percent,double lots_mm2,double per_mm2,double risk_mm3,double risk_mm4)
  {
   double balance=AccountBalance();
   double tick_value=MarketInfo(instrument,MODE_TICKVALUE);
    
   switch(method)
     {
      case MM_RISK_PERCENT_PER_ADR:
         if(pips>0) lots=((balance*_risk_percent_per_ADR)/pips)/tick_value;
         break;
      case MM_RISK_PERCENT:
         if(pips>0) lots=((balance*risk_mm1_percent)/pips)/tick_value;
         break;
      /*case MM_FIXED_RATIO:
         lots=balance*lots_mm2/per_mm2;
         break;
      case MM_FIXED_RISK:
         if(pips>0) lots=(risk_mm3/tick_value)/pips;
         break;
      case MM_FIXED_RISK_PER_POINT:
         lots=risk_mm4/tick_value;
         break;*/
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
int count_orders(ENUM_ORDER_SET type_needed=ORDER_SET_ALL,int magic=-1,int pool=MODE_TRADES, int pools_end_index=-1,int x_seconds_before=-1,datetime since_time=-1) // With pool, you can define whether to count current orders (MODE_TRADES) or closed and cancelled orders (MODE_HISTORY).
  {
   int count=0;

   for(int i=pools_end_index;i>=0;i--) // You have to start iterating from the lower part (or 0) of the order array because the newest trades get sent to the start. Interate through the index from a not excessive index position (the middle of an index) to OrdersTotal()-1 // the oldest order in the list has index position 0
     {
      if(OrderSelect(i,SELECT_BY_POS,pool)) // Problem: if the pool is MODE_HISTORY, that can be a lot of data to search. So make sure you calculated a not-excessive pools_end_index (the oldest order that is acceptable).
        {
         if(magic==-1 || magic==OrderMagicNumber())
           {
            if(x_seconds_before>0 && since_time>0) // only count them if they are within X seconds of the specified time
               if(OrderOpenTime()<(since_time-x_seconds_before)) break; // if the time the order was opened is before the time the user wants to start counting orders, do not count it

            int actual_type=OrderType();
            //int ticket=OrderTicket(); // the ticket variable may not be needed in the code of this function
            switch(type_needed)
              {
               case ORDER_SET_BUY:
                  if(actual_type==OP_BUY) count++;
                  break;
               case ORDER_SET_SELL:
                  if(actual_type==OP_SELL) count++;
                  break;
               case ORDER_SET_BUY_LIMIT:
                  if(actual_type==OP_BUYLIMIT) count++;
                  break;
               case ORDER_SET_SELL_LIMIT:
                  if(actual_type==OP_SELLLIMIT) count++;
                  break;
               /*case ORDER_SET_BUY_STOP:
                  if(actual_type==OP_BUYSTOP) count++;
                  break;
               case ORDER_SET_SELL_STOP:
                  if(actual_type==OP_SELLSTOP) count++;
                  break;*/
               case ORDER_SET_LONG:
                  if(actual_type==OP_BUY || actual_type==OP_BUYLIMIT /*|| actual_type==OP_BUYSTOP*/)
                  count++;
                  break;
               case ORDER_SET_SHORT:
                  if(actual_type==OP_SELL || actual_type==OP_SELLLIMIT /*|| actual_type==OP_SELLSTOP*/)
                  count++;
                  break;
               case ORDER_SET_SHORT_LONG_LIMIT_MARKET:
                  if(actual_type==OP_BUY || actual_type==OP_BUYLIMIT || actual_type==OP_SELL || actual_type==OP_SELLLIMIT /*|| ordertype==OP_SELLSTOP*/)
                  count++;
                  break;
               case ORDER_SET_LIMIT:
                  if(actual_type==OP_BUYLIMIT || actual_type==OP_SELLLIMIT)
                  count++;
                  break;
               /*case ORDER_SET_STOP:
                  if(actual_type==OP_BUYSTOP || actual_type==OP_SELLSTOP)
                  count++;
                  break;*/
               case ORDER_SET_MARKET:
                  if(actual_type<=1) count++;
                  break;
               case ORDER_SET_PENDING:
                  if(actual_type>1) count++;
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
bool virtualstop_check_order(int ticket,int sl,int tp,int max_slippage)
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
         result=exit_order(ticket,max_slippage);
        }
     }
   else if(OrderType()==OP_SELL)
     {
      double virtual_stoploss=OrderOpenPrice()+(sl*point);
      double virtual_takeprofit=OrderOpenPrice()-(tp*point);
      if((sl>0 && compare_doubles(OrderClosePrice(),virtual_stoploss,digits)>=0) || 
         (tp>0 && compare_doubles(OrderClosePrice(),virtual_takeprofit,digits)<=0))
        {
         result=exit_order(ticket,max_slippage);
        }
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// use this function  in case you do not want the broker to know where your stop is
void virtualstop_check_all_orders(int sl,int tp,int magic=-1,int max_slippage=50)
  {
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS))
         if(magic==-1 || magic==OrderMagicNumber())
            virtualstop_check_order(OrderTicket(),sl,tp,max_slippage);
     }
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