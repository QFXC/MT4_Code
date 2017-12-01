//+------------------------------------------------------------------+
//|                                            Relativity_EA_V01.mq4 |
//|                                                 Quant FX Capital |
//|                                   https://www.quantfxcapital.com |
//+------------------------------------------------------------------+
#property copyright "Quant FX Capital"
#property link      "https://www.quantfxcapital.com"
#property version   "1.05"
#property strict
// TODO: When strategy testing, make sure you have all the M5, D1, and W1 data because it is reference in the code.
// TODO: Always use NormalizeDouble() when computing the price (or lots or ADR?) yourself. This is not necessary for internal functions like OrderOPenPrice(), OrderStopLess(),OrderClosePrice(),Bid,Ask
// TODO: Use the compare_doubles() function to compare two doubles.
// TODO: You may want to pass some values by reference (which means changing the value of a variable inside of a function by calling a different function.)
// Remember: It has to be for a broker that will give you D1 data for at least around 6 months in order to calculate the Average Daily Range (ADR).
// Remember: This EA calls the OrdersHistoryTotal() function which counts the ordres of the "Account History" tab of the terminal. Set the history there to 3 days.

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
enum ENUM_RANGE
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
   ORDER_SET_BUY,
   ORDER_SET_SELL,
   ORDER_SET_BUY_LIMIT,
   ORDER_SET_SELL_LIMIT, 
   /*ORDER_SET_BUY_STOP,
   ORDER_SET_SELL_STOP,*/
   ORDER_SET_LONG,
   ORDER_SET_SHORT,
   ORDER_SET_LIMIT,
   /*ORDER_SET_STOP,*/
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
	string symbol=NULL;
  /*input*/ bool auto_adjust_broker_digits=true;
  static int EA_1_magic_num; // An EA can only have one magic number. Used to identify the EA that is managing the order. TODO: see if it can auto generate the magic number every time the EA is loaded on the chart.
  static bool uptrend_triggered=true;
  static bool downtrend_triggered=true;
  static double average_spread_yesterday=0;
   
// virtual stoploss variables
	int virtual_sl=0; // TODO: Change to a percent of ADR
	int virtual_tp=0; // TODO: Change to a percent of ADR
	
// breakeven variables
	double breakeven_threshold=500; // TODO: Change this to a percent of ADR. The percent of ADR in profit before setting the stop to breakeven.
	double breakeven_plus=0; // plus allows you to move the stoploss +/- from the entry price where 0 is breakeven, <0 loss zone, and >0 profit zone
	
// trailing stop variables
	double trail_value=20; // TODO: Change to a percent of ADR
	double trail_threshold=500; // TODO: Change to a percent of ADR
	double trail_step=20; // the minimum difference between the proposed new value of the stoploss to the current stoploss price // TODO: Change to a percent of ADR
	
	//input bool only_enter_on_new_bar=false; // Should you only enter trades when a new bar begins?
	input bool exit_opposite_signal=true; //exit_opposite_signal: Should the EA exit trades when there is a signal in the opposite direction?
  bool long_allowed=true; // Are long trades allowed?
	bool short_allowed=true; // Are short trades allowed?
	
	input string space_1="----------------------------------------------------------------------------------------";
	
	input int max_directional_trades_at_once=1; //max_directional_trades_at_once: How many trades can the EA enter at the same time in the one direction on the current chart? (If 1, a long and short trade (2 trades) can be opened at the same time.)input int max_num_EAs_at_once=28; // What is the maximum number of EAs you will run on the same instance of a platform at the same time?
	input int max_trades_within_x_hours=1; //max_trades_within_x_hours: 0-x days (x depends on the setting of the Account History tab of the terminal). // How many trades are allowed to be opened (even if they are closed now) within the last x_hours?
	input double x_hours=3; //x_hours: Any whole or fraction of an hour.
	input int max_directional_trades_each_day=1; //max_directional_trades_each_day: How many trades are allowed to be opened (even if they are close now) after the start of each current day?
  
  input string space_2="----------------------------------------------------------------------------------------";
  
// time filters - only allow EA to enter trades between a range of time in a day
	input int start_time_hour=0; //start_time_hour: 0-23
	input int start_time_minute=30; //start_time_minute: 0-59
	input int end_time_hour=23; //end_time_hour: 0-23
	input int end_time_minute=0; //end_time_minute: 0-59
	input bool trade_friday=false;
	/*input*/ int fri_end_time_hour=14; //fri_end_time_hour: 0-23
	/*input*/ int fri_end_time_minute=0; //fri_end_time_minute: 0-59
  input int exit_time_hour=23; //exit_time_hour: should be before the trading range start_time and after trading range end_time
  input int exit_time_minute=30; //exit_time_minute: 0-59
	input int gmt_hour_offset=-2; //gmt_hour_offset: -3 if using Gain Capital. The value of 0 refers to the time zone used by the broker (seen as 0:00 on the chart). Adjust this offset hour value if the broker's 0:00 server time is not equal to when the time the NY session ends their trading day.
  
  input string space_3="----------------------------------------------------------------------------------------";
  
// enter_order
  /*input*/ ENUM_SIGNAL_SET SIGNAL_SET=SIGNAL_SET_1; //SIGNAL_SET: Which signal set would you like to test? (the details of each signal set are found in the signal_entry function)
  // TODO: make sure you have coded for the scenerios when each of these is set to 0
	input double pullback_percent=0.35; //pullback_percent:  Must be positive. If you want a buy or sell limit order, it must be positive.
	input double takeprofit_percent=1.3; //takeprofit_percent: Must be a positive number. (What % of ADR should you tarket?)
  double stoploss_percent=1.0; //stoploss_percent: Must be a positive number.
	/*input*/ double max_spread_percent=.1; //max_spread_percent: Must be positive. What percent of ADR should the spread be less than? (Only for immediate orders and not pending.)
	/*input*/ bool based_on_raw_ADR=true; //based_on_raw_ADR: Should the max_spread_percent be calculated from the raw ADR?
	
	/*input*/ int entering_max_slippage_pips=5; //entering_max_slippage_pips: Must be in whole number. // TODO: Is this really pips and not points?
//input int unfavorable_slippage=5;
	string EA_name="ADR Relativity"; // allows the robot to enter a description for the order. An empty string is a default value
//exit_order
	/*input*/ int exiting_max_slippage_pips=50; //exiting_max_slippage_pips: Must be in whole number.
	
	input double active_order_expire=30; //active_order_expire: Any hours or fractions of hour(s). How many hours can a trade be on that hasn't hit stoploss or takeprofit?
	input double pending_order_expire=7;//pending_order_expire: Any hours or fractions of hour(s). In how many hours do you want your pending orders to expire?
	/*input*/ bool market_exec=false; //market_exec: False means that it is instant execution rather than market execution. Not all brokers offer market execution. The rule of thumb is to never set it as instant execution if the broker only provides market execution.
	color arrow_color_short=clrRed;
	color arrow_color_long=clrGreen;
	
  input string space_4="----------------------------------------------------------------------------------------";
  
//calculate_lots/mm variables
	ENUM_MM money_management=MM_RISK_PERCENT_PER_ADR;
	/*input*/ double risk_percent_per_ADR=0.03; //risk_percent_per_ADR: percent risked when using the MM_RISK_PER_ADR_PERCENT money management calculations. Any amount of digits after the decimal point. Note: This is not the percent of your balance you will be risking.
	double mm1_risk_percent=0.02; //mm1_risk_percent: percent risked when using the MM_RISK_PERCENT money management calculations
   // these variables will not be used with the MM_RISK_PERCENT money management strategy
	double lot_size=0.0;
	/*double mm2_lots=0.1;
	double mm2_per=1000;
	double mm3_risk=50;
	double mm4_risk=50;*/
	
  input string space_5="----------------------------------------------------------------------------------------";
  
// Market Trends
  input double H1s_to_roll=3.5; //H1s_to_roll: Only divisible by .5 // How many hours should you roll to determine a short term market trend?
  input double max_weekend_gap_percent=.15; //max_weekend_gap_percent: What is the maximum weekend gap (as a percent of ADR) for H1s_to_roll to not take the previous week into account?
  input bool include_last_week=true; //include_last_week: Should the EA take Friday's moves into account when starting to determine length of the current move?
  static double ADR_pts;
  double point_multiplier=1; // .001=Point
  double new_point=1; //100*Point*10;

  input string space_7="----------------------------------------------------------------------------------------";
// ADR()
  /*input*/ int num_ADR_months=2; //num_ADR_months: How months back should you use to calculate the average ADR? (Divisible by 1)
  input double change_ADR_percent=-.2; //change_ADR_percent: this can be a 0, negative, or positive decimal or whole number. 
// TODO: make sure you have coded for the scenerios when each of these is set to 0
  /*input*/ double above_ADR_outlier_percent=1.4; //above_ADR_outlier_percent: Can be any decimal with two numbers after the decimal point or a whole number. // How much should the ADR be surpassed in a day for it to be neglected from the average calculation?
  /*input*/ double below_ADR_outlier_percent=.6; //below_ADR_outlier_percent: Can be any decimal with two numbers after the decimal point or a whole number. // How much should the ADR be under in a day for it to be neglected from the average calculation?

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
    //get_new_point();
    get_changed_ADR_pts(H1s_to_roll,below_ADR_outlier_percent,above_ADR_outlier_percent,change_ADR_percent);
  
    double tick_value=MarketInfo(symbol,MODE_TICKVALUE);
    double point=MarketInfo(symbol,MODE_POINT);
    double spread=MarketInfo(symbol,MODE_SPREAD);
    double bid_price=MarketInfo(symbol,MODE_BID);
    double min_distance_pts=MarketInfo(symbol,MODE_STOPLEVEL);
    double min_lot=MarketInfo(symbol,MODE_MINLOT);
    double max_lot=MarketInfo(symbol,MODE_MAXLOT);
    int lot_digits=(int) -MathLog10(MarketInfo(symbol,MODE_LOTSTEP));
    int digits=(int)MarketInfo(symbol,MODE_DIGITS);
    datetime current_bar_open_time=iTime(symbol,PERIOD_M5,0);        
    datetime current_time=(datetime)MarketInfo(symbol,MODE_TIME);
    
    
    Print("tick_value: ",DoubleToStr(tick_value));
    Print("Point: ",DoubleToStr(point));
    Print("Point: ",DoubleToStr(Point));
    Print("Point: ",DoubleToStr(Point()));
    Print("new_point (Point*10): ",DoubleToStr(new_point));
    Print("spread before the function calls: ",DoubleToStr(spread));
    Print("ADR_pts: ",DoubleToStr(ADR_pts)); 
    Print("bid_price: ",DoubleToStr(bid_price));
    Print("min_distance_pts*Point: ",DoubleToStr(min_distance_pts*Point));
    Print("min_lot: ",DoubleToStr(min_lot)," .01=micro lots, .1=mini lots, 1=standard lots");
    Print("max_lot: ",DoubleToStr(max_lot));
    Print("lot_digits: ",IntegerToString(lot_digits)," after the decimal point.");
    Print("broker digits: ",IntegerToString(digits)," after the decimal point.");
    Print("broker digits: ",IntegerToString(Digits())," after the decimal point.");

      // TODO: check if the broker has Sunday's as a server time, and, if not, block all the code you wrote to count Sunday's from running
      
      
      EA_1_magic_num=generate_magic_num(signal_set);
      bool input_variables_valid=all_user_input_variables_valid();
      
      int range_start_time=(start_time_hour*3600)+(start_time_minute*60);
      int range_end_time=(end_time_hour*3600)+(end_time_minute*60);
      int exit_time=(exit_time_hour*3600)+(exit_time_minute*60);
  
     // Print("The EA will not work properly. The input variables max_trades_in_direction, max_num_EAs_at_once, and max_trades_within_x_hours can't be 0 or negative.");
    
  
    Print(Symbol(),"'s Magic Number: ",IntegerToString(EA_1_magic_num));
    if(exit_time>range_start_time && exit_time<range_end_time && !input_variables_valid)
      {
        Print("The initialization of the EA failed. Make sure that the trade exit_time_hour and exit_time_minute combination does not fall within the trading range start and end times or else there will be trouble!");
        Alert("The initialization of the EA failed. Make sure that the trade exit_time_hour and exit_time_minute combination does not fall within the trading range start and end times or else there will be trouble!");
        return(INIT_FAILED);
      }
    else if(EA_1_magic_num<=0)
      {
        Print("The initialization of the EA failed. There is not a valid magic number for the Expert Advisor (EA). Without one, the EA will not run correctly. Get a MQL4 programmer check the code to find out why.");
        Alert("The initialization of the EA failed. There is not a valid magic number for the Expert Advisor (EA). Without one, the EA will not run correctly. Get a MQL4 programmer check the code to find out why.");
        return(INIT_FAILED);
      }
    else if(!input_variables_valid)
      {
        Print("The initialization of the EA failed. One or more of the user input variables are not valid. The EA will not run correctly.");
        Alert("The initialization of the EA failed. One or more of the user input variables are not valid. The EA will not run correctly.");
        return(INIT_FAILED);
      }
    else
      {
        Print("The initialization of the EA finished successfully.");
        return(INIT_SUCCEEDED);
      }
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
// Runs once when the EA is turned off
void OnDeinit(const int reason)
  {

   //The first way to get the uninitialization reason code
   /*Print(__FUNCTION__,"_Uninitalization reason code = ",reason);*/

   //The second way to get the uninitialization reason code
   Print(__FUNCTION__,"_UninitReason = ",getUninitReasonText(_UninitReason));

   Print("If there are no errors, then the ",EA_name," EA for ",Symbol()," has been successfully deinitialized.");
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
  static bool ready=false, in_time_range=false;
// timeframe changes
  bool is_new_D1_bar;
  bool is_new_M5_bar;
  bool wait_next_M5_on_load=false; //wait_next_M5_on_load: This setting currently affects all bars (including D1) so do not set it to true unless code changes are made. // When you load the EA, should it wait for the next bar to load before giving the EA the ability to enter a trade or calculate ADR?
  
void OnTick()
  {
   is_new_M5_bar=is_new_M5_bar(wait_next_M5_on_load);
   is_new_D1_bar=is_new_D1_bar();
   datetime current_time=TimeCurrent();
   int exit_signal=TRADE_SIGNAL_NEUTRAL, exit_signal_2=TRADE_SIGNAL_NEUTRAL; // 0
   int _exiting_max_slippage=exiting_max_slippage_pips;
   bool Relativity_EA_2_on=false;
   
   cleanup_pending_orders();

   
   Relativity_EA(EA_1_magic_num,current_time,exit_signal,exit_signal_2,_exiting_max_slippage);
   
   if(Relativity_EA_2_on) Relativity_EA(EA_1_magic_num,current_time,exit_signal,exit_signal_2,_exiting_max_slippage);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Relativity_EA(int magic,datetime current_time,int exit_signal,int exit_signal_2,int _exiting_max_slippage)
  {
   //string _symbol=symbol;
   
   exit_signal=signal_exit(SIGNAL_SET); // The exit signal should be made the priority and doesn't require in_time_range or adr_generated to be true

   if(exit_signal==TRADE_SIGNAL_VOID)       exit_all_trades_set(_exiting_max_slippage,ORDER_SET_ALL,magic); // close all pending and orders for the specific EA's orders. Don't do validation to see if there is an EA_magic_num because the EA should try to exit even if for some reason there is none.
   else if(exit_signal==TRADE_SIGNAL_BUY)   exit_all_trades_set(_exiting_max_slippage,ORDER_SET_SHORT,magic);
   else if(exit_signal==TRADE_SIGNAL_SELL)  exit_all_trades_set(_exiting_max_slippage,ORDER_SET_LONG,magic);

   // Breakeven (comment out if this functionality is not required)
   //if(breakeven_threshold>0) breakeven_check_all_orders(breakeven_threshold,breakeven_plus,order_magic);
   
   // Trailing Stop (comment out of this functionality is not required)
   //if(trail_value>0) trailingstop_check_all_orders(trail_value,trail_threshold,trail_step,order_magic);
   //   virtualstop_check(virtual_sl,virtual_tp); 

   if(is_new_M5_bar) // only check if it is in the time range once the EA is loaded and, then, afterward at the beginning of every M5 bar
     {
      //Print("Got past is_new_M5_bar");
      exit_all_trades_set(_exiting_max_slippage,ORDER_SET_MARKET,magic,(int)(active_order_expire*3600),current_time); // This runs every 5 minutes (whether the time is in_time_range or not). It only exit trades that have been on for too long and haven't hit stoploss or takeprofit.
      in_time_range=in_time_range(current_time,start_time_hour,start_time_minute,end_time_hour,end_time_minute,fri_end_time_hour,fri_end_time_minute,gmt_hour_offset);
      get_moves_start_bar(H1s_to_roll,gmt_hour_offset,max_weekend_gap_percent,include_last_week); // this is here so the vertical line can get moved every 5 minutes

      if(in_time_range==true && ready==false && average_spread_yesterday!=-1) 
        {
         get_changed_ADR_pts(H1s_to_roll,below_ADR_outlier_percent,above_ADR_outlier_percent,change_ADR_percent);
         average_spread_yesterday=calculate_avg_spread_yesterday(symbol);
         
         /*static bool flag=true;
         if(flag) 
          {
            Print("Relativity_EA_1: average_spread_yesterday: ",DoubleToString(average_spread_yesterday));
            flag=false;
          }*/
         
         bool is_acceptable_spread=acceptable_spread(symbol,max_spread_percent,based_on_raw_ADR,average_spread_yesterday,false);
         
         if(is_acceptable_spread==false) 
           {
            /*Steps that were used to calculate percent_allows_trading:
            
            double max_spread=((ADR_pips*Point)*max_spread_percent);
            double spread_diff=average_spread_yesterday-max_spread;
            double spread_diff_percent=spread_diff/(ADR_pips*Point);
            double percent_allows_trading=spread_diff_percent+max_spread_percent;*/
            
            double percent_allows_trading=NormalizeDouble(((average_spread_yesterday-(ADR_pts*max_spread_percent))/ADR_pts)+max_spread_percent,3);
            
            Alert(Symbol()," can't be traded today because the average spread yesterday does not meet your max_spread_percent (",
                  DoubleToStr(max_spread_percent,3),") of ADR criteria. The average spread yesterday was ",
                  DoubleToStr(average_spread_yesterday,3),
                  ". A max_spread_percent value above ",
                  DoubleToStr(percent_allows_trading,3),
                  " would have allowed the EA make trades in this currency pair today.");
            average_spread_yesterday=-1; // keep this at -1 because an if statement depends on it
           }
         if(ADR_pts>0 && magic>0 && is_acceptable_spread==true)
           {
            ready=true; // the ADR and average spread yesterday that has just been calculated won't generate again until after the cycle of not being in the time range completes
            uptrend_triggered=false;
            downtrend_triggered=false;
           }
         else 
           {
            ready=false;
            uptrend_triggered=true;
            downtrend_triggered=true;;
            // never assign average_spread_yesterday to anything in this scope
           }
        }
     }
   if(ready && in_time_range)
     {
      //Print("ready && in_time_range");
      int enter_signal=TRADE_SIGNAL_NEUTRAL; // 0
    
      enter_signal=signal_pullback_after_ADR_triggered(); // this is the first signal and will apply to all signal sets so it gets run first
      //enter_signal=signal_compare(enter_signal,signal_entry(SIGNAL_SET),false); // The entry signal requires in_time_range, adr_generated, and EA_magic_num>0 to be true.      

      if(enter_signal>0)
        {
         int days_seconds=(int)(current_time-(iTime(symbol,PERIOD_D1,0))+(gmt_hour_offset*3600)); // i am assuming it is okay to typecast a datetime (iTime) into an int since datetime is count of the number of seconds since 1970
         //int efficient_end_index=MathMin((MathMax(max_trades_within_x_hours*x_hours,max_directional_trades_each_day*24)*max_directional_trades_at_once*max_num_EAs_at_once-1),OrdersHistoryTotal()-1); // calculating the maximum orders that could have been placed so at least the program doesn't have to iterate through all orders in history (which can slow down the EA)
         
         if(enter_signal==TRADE_SIGNAL_BUY)
           {
            if(count_similar_orders(BUYING_MODE)>1) return; // count all similar orders for all magic numbers in the account
            ENUM_ORDER_SET order_set=ORDER_SET_LONG;
            ENUM_ORDER_SET order_set2=ORDER_SET_SHORT_LONG_LIMIT_MARKET;
            
            if(exit_opposite_signal) exit_all_trades_set(_exiting_max_slippage,ORDER_SET_SELL,magic);
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
                                                 (int)(x_hours*3600),
                                                 current_time);
            int current_long_count=count_orders (order_set, // should be last because the harder and more similar ones should go first
                                                 magic,
                                                 MODE_TRADES,
                                                 OrdersTotal()-1,
                                                 0,
                                                 current_time); // counts all long (active and pending) orders for the current EA
            
            if(current_long_count<max_directional_trades_at_once &&  // just long
               opened_recently_count<max_trades_within_x_hours &&    // long and short
               opened_today_count<max_directional_trades_each_day)   // just long
              {
               //if(!only_enter_on_new_bar || (only_enter_on_new_bar && is_new_M5_bar))

               RefreshRates();
               bool overbought_1=over_extended_trend(3,BUYING_MODE,HIGH_MINUS_LOW,.75,3,false);
               bool overbought_2=over_extended_trend(3,BUYING_MODE,OPEN_MINUS_CLOSE_ABSOLUTE,.75,3,false);
               if(overbought_1 || overbought_2) return;
               try_to_enter_order(OP_BUY,magic,entering_max_slippage_pips); // TODO: uncomment this line

              }
           }
         else if(enter_signal==TRADE_SIGNAL_SELL)
           {
            if(count_similar_orders(SELLING_MODE)>1) return; // count all similar orders for all magic numbers in the account
            
            ENUM_ORDER_SET order_set=ORDER_SET_SHORT;
            ENUM_ORDER_SET order_set2=ORDER_SET_SHORT_LONG_LIMIT_MARKET;
            
            if(exit_opposite_signal) exit_all_trades_set(_exiting_max_slippage,ORDER_SET_BUY,magic);
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
                                                 (int)(x_hours*3600),
                                                 current_time);
            int current_short_count=count_orders(order_set, // should be last because the harder and more similar ones should go first
                                                 magic,
                                                 MODE_TRADES,
                                                 OrdersTotal()-1,
                                                 0,
                                                 current_time); // counts all short (active and pending) orders for the current EA
            
            if(current_short_count<max_directional_trades_at_once && // just short
               opened_recently_count<max_trades_within_x_hours &&    // short and long
               opened_today_count<max_directional_trades_each_day)   // just short
              {
               //if(!only_enter_on_new_bar || (only_enter_on_new_bar && is_new_M5_bar))

               RefreshRates();
               bool oversold_1=over_extended_trend(3,SELLING_MODE,HIGH_MINUS_LOW,.75,3,false);
               bool oversold_2=over_extended_trend(3,SELLING_MODE,OPEN_MINUS_CLOSE_ABSOLUTE,.75,3,false);
               if(oversold_1 || oversold_2) return;
               try_to_enter_order(OP_SELL,magic,entering_max_slippage_pips); // TODO: remove comments
              }
           }
        }
     }
    else
     {
       ready=false; // this makes sure to set it to false so when the time is within the time range again, the ADR can get generated
       uptrend_triggered=true;
       downtrend_triggered=true;
       ADR_pts=0;
       average_spread_yesterday=0; // do not change this from 0
       //Print("Out of time range");

       if(is_new_M5_bar)
        {
         bool time_to_exit=time_to_exit(current_time,exit_time_hour,exit_time_minute,gmt_hour_offset);
         //Alert(time_to_exit);
         if(time_to_exit==true) exit_all_trades_set(_exiting_max_slippage,ORDER_SET_ALL,magic); // this is the special case where you can exit open and pending trades based on a specified time (this should have been set to be outside of the trading time range)
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/*void get_new_point()
  {  
    new_point=10;
    if(auto_adjust_broker_digits==true && (Digits()==3 || Digits()==5))
      {
        Print("Your broker's rates have ",IntegerToString(Digits())," digits after the decimal point. Therefore, to keep the math in the EA as it was intended, all pip values will be automatically multiplied by 10. You do not have to do anything.");
        new_point=10;
      }
  }*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------
int ma_period=150;
int ma_shift=0;
ENUM_MA_METHOD ma_method=MODE_SMA;
ENUM_APPLIED_PRICE ma_applied=PRICE_MEDIAN;
int ma_index=1;

int signal_MA_crossover(double a1,double a2,double b1,double b2)
  {
   ENUM_TRADE_SIGNAL signal=TRADE_SIGNAL_NEUTRAL;
   if(a1<b1 && a2>=b2)
     {
      signal=TRADE_SIGNAL_BUY;
     }
   else if(a1>b1 && a2<=b2)
     {
      signal=TRADE_SIGNAL_SELL;
     }
   return signal;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int signal_MA()
  {
   double ma=iMA(NULL,0,ma_period,ma_shift,ma_method,ma_applied,ma_index);
   double ma1=iMA(NULL,0,ma_period,ma_shift,ma_method,ma_applied,ma_index+1);
   double close=iClose(NULL,0,ma_index);
   double close1=iClose(NULL,0,ma_index+1);
   if(ma<close && ma1>close1)
     {
      return TRADE_SIGNAL_BUY;
     }
   else if(ma>close && ma1<close1)
     {
      return TRADE_SIGNAL_SELL;
     }
   return 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool over_extended_trend(int days_to_check,ENUM_DIRECTIONAL_MODE mode,ENUM_RANGE range,double days_range_percent_threshold,int num_to_be_true,bool dont_analyze_today=false)
    {
    static int new_days_to_check=0;
    int digits=(int)MarketInfo(symbol,MODE_DIGITS);
    double ADR_points_threshold=NormalizeDouble(ADR_pts*days_range_percent_threshold,digits);
    double previous_days_close=-1;
    double bid_price=MarketInfo(symbol,MODE_BID); // RefreshRates() always has to be called before getting the price. In this case, it was run before calling this function.
    bool answer=false;
    int uptrend_count=0, downtrend_count=0;
    int sunday_count=0;
    int lower_index=(int)dont_analyze_today;
    
    if(is_new_D1_bar || new_days_to_check==0) // get the new value of the static sunday_count the first time it is run or if it is a new day
      {
        new_days_to_check=0; // do not delete this line
        for(int i=days_to_check-1+lower_index;i>=lower_index;i--)
          {
            int day=TimeDayOfWeek(iTime(symbol,PERIOD_D1,i));
          
            if(day==0) // count Sundays
              {
                sunday_count++;
              }
          }    
      }
    if(sunday_count>0) new_days_to_check=sunday_count+days_to_check;
    if(mode==BUYING_MODE)
      {
        for(int i=new_days_to_check-1+lower_index;i>=lower_index;i++) // days_to_check should be past days to check + today
          {
            double open_price=iOpen(symbol,PERIOD_D1,i), close_price=iClose(symbol,PERIOD_D1,i);
            
            if(new_days_to_check!=days_to_check) // if there are Sundays in this range
              {
                int day=TimeDayOfWeek(iTime(symbol,PERIOD_D1,i));
                if(day==0) break; // if the bar is Sunday, skip this day            
              }
            double days_range=0;
            if(range==HIGH_MINUS_LOW)
              {
                if(i!=0) days_range=iHigh(symbol,PERIOD_D1,i)-iLow(symbol,PERIOD_D1,i);
                else days_range=bid_price-iLow(symbol,PERIOD_D1,i);
              }
            else if(range==OPEN_MINUS_CLOSE_ABSOLUTE)
              {
                if(i!=0) days_range=close_price-open_price;
                else days_range=bid_price-open_price; // can be negative
              }
            if(days_range>=ADR_points_threshold) // only positive day_ranges pass this point // TODO: use compare_doubles()?
              { 
                if(i==new_days_to_check-1+lower_index)
                  {
                    if(open_price>close_price) uptrend_count++;  // TODO: use compare_doubles()?
                    else downtrend_count++;
                    break;
                  }
                previous_days_close=iClose(symbol,PERIOD_D1,i+1); // this is different than the close_price because it is i+1
                if(close_price>previous_days_close) // TODO: use compare_doubles()?
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
        for(int i=new_days_to_check-1+lower_index;i>=lower_index;i++) // days_to_check should be past days to check + today
          {
            double open_price=iOpen(symbol,PERIOD_D1,i), close_price=iClose(symbol,PERIOD_D1,i);
            
            if(new_days_to_check!=days_to_check)
              {
                int day=TimeDayOfWeek(iTime(symbol,PERIOD_D1,i));
                if(day==0) break; // if the bar is Sunday, skip this day
              }
            double days_range=0;
            if(range==HIGH_MINUS_LOW) 
              {
                if(i!=0) days_range=iHigh(symbol,PERIOD_D1,i)-iLow(symbol,PERIOD_D1,i);
                else days_range=iHigh(symbol,PERIOD_D1,i)-bid_price;
              }
            else if(range==OPEN_MINUS_CLOSE_ABSOLUTE)
              {
                if(i!=0) days_range=open_price-close_price;
                else days_range=open_price-bid_price;
              }
            if(days_range>=ADR_points_threshold) // only positive day_ranges pass this point // TODO: use compare_doubles()?
              { 
                if(i==new_days_to_check-1+lower_index)
                  {
                    if(open_price>close_price) downtrend_count++; // TODO: use compare_doubles()?
                    else uptrend_count++;
                    break;
                  }  
                previous_days_close=iClose(symbol,PERIOD_D1,i+1); // this is different than close_price because it is i+1
                if(close_price<previous_days_close) // TODO: use compare_doubles()?
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
    //return false; // TODO: delete this line
    }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int signal_pullback_after_ADR_triggered()
  {
    int signal=TRADE_SIGNAL_NEUTRAL;
 
    if(!uptrend_triggered)
      {
        RefreshRates();
        if(uptrend_ADR_threshold_price_met(false)>0)
          {
            return signal=TRADE_SIGNAL_BUY;
          }
      }
   // for a buying signal, take the level that adr was triggered and subtract the pullback_pips to get the pullback_entry_price
   // if the pullback_entry_price is met or exceeded, signal = TRADE_SIGNAL_BUY
    if(!downtrend_triggered)
      {
        RefreshRates();
        if(downtrend_ADR_threshold_price_met(false)>0) 
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
      //signal=signal_compare(signal,signal_x_consecutive_directional_days(),false);
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
              another_variable=NormalizeDouble(another_variable,2);
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

started work on a different option if the one above does not work out.
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
bool in_time_range(datetime time,int start_hour,int start_min,int end_hour,int end_min,int fri_end_time_hr, int fri_end_time_min, int gmt_offset=0)
  {
   int day=DayOfWeek();
   if(day==0) 
     return false; // if the broker's server time says it is Sunday, you are not in your trading time range // TODO: uncomment this line
     
   if(day==5)
     {
      if(trade_friday==false) return false;
      end_hour=fri_end_time_hr;
      end_min=fri_end_time_min;
     }
   if(gmt_offset!=0) 
     {
      start_hour+=gmt_offset;
      end_hour+=gmt_offset;
     }
// Since a non-zero gmt_offset will make the start and end hour go beyond acceptable paremeters (below 0 or above 23), change the start_hour and end_hour to military time.
   if(start_hour>23) start_hour=(start_hour-23)-1;
   else if(start_hour<0) start_hour=(23+start_hour)+1;
   if(end_hour>23) end_hour=(end_hour-23)-1;
   else if(end_hour<0) end_hour=(23+end_hour)+1;
   
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
   
   //return true; // TODO: delete this line
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool time_to_exit(datetime time,int exit_hour,int exit_min,int gmt_offset=0) 
  {
   string instrument=Symbol();
   if(gmt_offset!=0) 
     {
      exit_hour+=gmt_offset;
      exit_hour+=gmt_offset;
     }
// Since a non-zero gmt_offset will make the start and end hour go beyond acceptable paremeters (below 0 or above 23), change the start_hour and end_hour to military time.
   if(exit_hour>23) exit_hour=(exit_hour-23)-1;
   else if(exit_hour<0) exit_hour=23+exit_hour+1;
     
   int hour=TimeHour(time);
   int minute=TimeMinute(time);
   int current_time=(hour*3600)+(minute*60);
   int exit_time=(exit_hour*3600)+(exit_min*60);

     if(exit_time==current_time)
      {
        if(ObjectFind(instrument+"_time_to_exit")<0) 
          {
            ObjectCreate(instrument+"_time_to_exit",OBJ_VLINE,0,TimeCurrent(),Bid);
            ObjectSet(instrument+"_time_to_exit",OBJPROP_COLOR,clrWhite);
          }
        else
          {
            ObjectMove(instrument+"_time_to_exit",0,TimeCurrent(),Bid);
          }
        return true; // this will only give the signal to exit for every tick for 1 minute per day
      }
     else return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_new_M5_bar(bool wait_for_next_bar=false)
  {
   static datetime bar_time=0;
   static double open_price=0;
   datetime current_bar_open_time=iTime(symbol,PERIOD_M5,0);
   double current_bar_open_price=iOpen(symbol,PERIOD_M5,0);
   int digits=(int)MarketInfo(symbol,MODE_DIGITS);
   
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
bool is_new_D1_bar()
  {
   static datetime bar_time=0;
   static double open_price=0;
   datetime current_bar_open_time=iTime(symbol,PERIOD_D1,0);
   double current_bar_open_price=iOpen(symbol,PERIOD_D1,0);
   int digits=(int)MarketInfo(symbol,MODE_DIGITS);
   
   if(bar_time==0 && open_price==0) // If it is the first time the function is called or it is the start of a new bar. This could be after the open time (aka in the middle) of a bar.
     {
      bar_time=current_bar_open_time;
      open_price=current_bar_open_price;
      return true;
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
double ADR_calculation(double low_outlier,double high_outlier/*,double change_by*/)
  {
     int three_mnth_sunday_count=0;
     int three_mnth_num_days=3*22; // There are about 22 business days a month.
     
     for(int i=three_mnth_num_days;i>0;i--) // count the number of Sundays in the past 6 months
        {
        int day=TimeDayOfWeek(iTime(symbol,PERIOD_D1,i));
        
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
      int day=TimeDayOfWeek(iTime(symbol,PERIOD_D1,i));
     
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
        int day=TimeDayOfWeek(iTime(symbol,PERIOD_D1,i));
             
        if(day>0) // if the day of week is not Sunday
          {
           double HOD=iHigh(symbol,PERIOD_D1,i);
           double LOD=iLow(symbol,PERIOD_D1,i);
           double days_range=HOD-LOD;
           double ADR_ratio=NormalizeDouble(days_range/six_mnth_ADR_avg,2); // ratio for comparing the current iteration with the 6 month average
           
           if(compare_doubles(ADR_ratio,low_outlier,2)==1 && compare_doubles(ADR_ratio,high_outlier,2)==-1) // filtering out outliers // TODO: you may not have to use compare_doubles()
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
        int day=TimeDayOfWeek(iTime(symbol,PERIOD_D1,i));
             
        if(day>0) // if the day of week is not Sunday
          {
           double HOD=iHigh(symbol,PERIOD_D1,i);
           double LOD=iLow(symbol,PERIOD_D1,i);
           double days_range=HOD-LOD;
           double ADR_ratio=NormalizeDouble(days_range/six_mnth_ADR_avg,2); // ratio for comparing the current iteration with the 6 month average
           
           if(compare_doubles(ADR_ratio,low_outlier,2)==1 && compare_doubles(ADR_ratio,high_outlier,2)==-1) // filtering out outliers // you may not have to use compare_doubles()
             {
              x_mnth_non_sunday_ADR_sum+=days_range;
              x_mnth_non_sunday_count++;
             }
          }
       }
     double adr_pts=NormalizeDouble((x_mnth_non_sunday_ADR_sum/x_mnth_non_sunday_count)*new_point,digits);
     Print("Calculate_ADR() returned: ",DoubleToStr(adr_pts));
     return adr_pts;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double get_raw_ADR_pts(double hours_to_roll,double low_outlier,double high_outlier/*,double change_by*/) // get the Average Daily Range
  {
    static double _adr_pts=0;
    int _num_ADR_months=num_ADR_months;
     
    if(low_outlier>high_outlier || _num_ADR_months<=0 || _num_ADR_months==NULL || MathMod(hours_to_roll,.5)!=0) // TODO: hours_to_roll is not used in this function except for this line
      {
        return -1; // if the user inputed the wrong outlier variables or a H1s_to_roll number that is not divisible by .5, it is not possible to calculate ADR
      }  
    if(_adr_pts==0 || is_new_D1_bar) // if it is the first time the function is called
      {
        double calculated_adr_pts=ADR_calculation(low_outlier,high_outlier/*,change_by*/);
        _adr_pts=calculated_adr_pts; // make the function remember the calculation the next time it is called
        return _adr_pts;
      }
    return _adr_pts; // if it is not the first time the function is called it is the middle of a bar, return the static adr
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void get_changed_ADR_pts(double hours_to_roll,double low_outlier,double high_outlier,double change_by) // get the Average Daily Range
  {
     double raw_ADR_pts=get_raw_ADR_pts(hours_to_roll,low_outlier,high_outlier);
     string instrument=Symbol();
     
     if(ObjectFind(instrument+"_ADR_pts")<0) 
      {
        ObjectCreate(instrument+"_ADR_pts",OBJ_TEXT,0,TimeCurrent(),Bid);
        ObjectSetText(instrument+"_ADR_pts","0",15,NULL,clrWhite);
      }
     
     if(raw_ADR_pts>0 && (change_by==0 || change_by==NULL))
      { 
        Print("The raw ADR for ",Symbol()," was generated. It is ",DoubleToString(raw_ADR_pts)," pips.");
        ADR_pts=NormalizeDouble(raw_ADR_pts,Digits);
        ObjectSetText(instrument+"_ADR_pts",DoubleToString(ADR_pts*100,Digits),0,NULL,clrWhite);
        ObjectMove(instrument+"_ADR_pts",0,TimeCurrent(),Bid+ADR_pts/4);
     
        //Print("raw_ADR_pts: ",DoubleToString(raw_ADR_pts));
      }
     else if(raw_ADR_pts>0)
      {
        double changed_ADR_pts=NormalizeDouble(((raw_ADR_pts*change_by)+raw_ADR_pts),Digits); // include the ability to increase\decrease the ADR by a certain percentage where the input is a global variable
        Print("The raw ADR for ",Symbol()," was just generated. It is ",DoubleToString(raw_ADR_pts,Digits)," pips. As requested by the user, it has been changed to ",DoubleToString(changed_ADR_pts)," pips.");
        ADR_pts=changed_ADR_pts;
        ObjectSetText(instrument+"_ADR_pts",DoubleToString(changed_ADR_pts*100,Digits),0);
        ObjectMove(instrument+"_ADR_pts",0,TimeCurrent(),Bid+ADR_pts/4);
      }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+  
int get_moves_start_bar(double _H1s_to_roll,int gmt_offset,double _max_weekend_gap_percent,bool _include_last_week=true)
  {
   int moves_start_bar=(int)_H1s_to_roll*12-1; // any double divisible by .5 will always be an integer when multiplied by an even number like 12 so it is okay to convert it into an int
   datetime week_start_open_time=iTime(symbol,PERIOD_W1,0)+(gmt_offset*3600); // The iTime of the week bar gives you the time that the week is 0:00 on the chart so I shifted the time to start when the markets actually start.
   int weeks_start_bar=iBarShift(symbol,PERIOD_M5,week_start_open_time,false);

   string instrument=Symbol();
   datetime time_anchor=iTime(symbol,PERIOD_M5,moves_start_bar);
   double price_anchor=iOpen(symbol,PERIOD_M5,moves_start_bar);
   
   if(ObjectFind(instrument+"_Move_Start")<0) ObjectCreate(instrument+"_Move_Start",OBJ_VLINE,0,time_anchor,price_anchor);
   if(moves_start_bar<=weeks_start_bar)
     {
      ObjectSet(instrument+"_Move_Start",OBJPROP_TIME1,iTime(instrument,PERIOD_M5,moves_start_bar));
      ObjectSet(instrument+"_Move_Start",OBJPROP_PRICE1,iOpen(instrument,PERIOD_M5,moves_start_bar));
      return moves_start_bar;
     }
   else if(_include_last_week)
     {
      double weekend_gap_points=MathAbs(iClose(symbol,PERIOD_W1,1)-iOpen(instrument,PERIOD_W1,0));
      double max_weekend_gap_points=NormalizeDouble(ADR_pts*_max_weekend_gap_percent,Digits);
      
      if(weekend_gap_points>=max_weekend_gap_points) // TODO: use compare_doubles()?
        {
          ObjectSet(instrument+"_Move_Start",OBJPROP_TIME1,iTime(instrument,PERIOD_M5,weeks_start_bar));
          ObjectSet(instrument+"_Move_Start",OBJPROP_PRICE1,iOpen(instrument,PERIOD_M5,weeks_start_bar));
          return weeks_start_bar; 
        }
      else 
        {
          ObjectSet(instrument+"_Move_Start",OBJPROP_TIME1,iTime(instrument,PERIOD_M5,moves_start_bar));
          ObjectSet(instrument+"_Move_Start",OBJPROP_PRICE1,iOpen(instrument,PERIOD_M5,moves_start_bar));
          return moves_start_bar;
        }
     }
   else
     {
      ObjectSet(instrument+"_Move_Start",OBJPROP_TIME1,iTime(instrument,PERIOD_M5,weeks_start_bar));
      ObjectSet(instrument+"_Move_Start",OBJPROP_PRICE1,iOpen(instrument,PERIOD_M5,weeks_start_bar));
      return weeks_start_bar;
     }
    //return moves_start_bar; // TODO: Delete this line
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double periods_pivot_price(ENUM_DIRECTIONAL_MODE mode)
  {
    int move_start_bar=get_moves_start_bar(H1s_to_roll,gmt_hour_offset,max_weekend_gap_percent,include_last_week);
    
    //Print("move start bar: ",move_start_bar);
    //Print("move start bar's time: ",TimeToString(iTime(symbol,PERIOD_M5,move_start_bar))," and price is: ",iOpen(symbol,PERIOD_M5,move_start_bar));
    
    if(mode==BUYING_MODE)
      { 
        double pivot_price=iLow(symbol,PERIOD_M5,iLowest(symbol,PERIOD_M5,MODE_LOW,move_start_bar,0)); // get the price of the bar that has the lowest price for the determined period
        //Print("The buying mode pivot_price is: ",DoubleToString(pivot_price));
        //Print("periods_pivot_price(): Bid: ",DoubleToString(Bid));     
        //Print("periods_pivot_price(): Bid-periods_pivot_price: ",DoubleToString(Bid-pivot_price));
        //Print("periods_pivot_price(): ADR_pts: ",DoubleToString(ADR_pts));
        return pivot_price;
      }
    else if(mode==SELLING_MODE)
      {
        double pivot_price=iHigh(symbol,PERIOD_M5,iHighest(symbol,PERIOD_M5,MODE_HIGH,move_start_bar,0)); // get the price of the bar that has the highest price for the determined period
        //Print("The selling mode pivot_price is: ",DoubleToString(pivot_price));
        //Print("periods_pivot_price(): Bid: ",DoubleToString(Bid));         
        //Print("periods_pivot_price(): periods_pivot_price-Bid: ",DoubleToString(pivot_price-Bid));
        //Print("periods_pivot_price(): ADR_pts: ",DoubleToString(ADR_pts));        
        return pivot_price;
      }
    else return -1;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double uptrend_ADR_threshold_price_met(bool get_current_bid_instead=false,int magic=-1)
  {
    static double LOP=0; // Low Of Period
    double current_bid=MarketInfo(symbol,MODE_BID); // TODO: always make sure RefreshRates() was called before. In this case, it was called before running this function.
    string instrument=Symbol();

    if(LOP==0) LOP=periods_pivot_price(BUYING_MODE);
    if(ObjectFind(instrument+"LOP")<0)
      {
        ObjectCreate(instrument+"LOP",OBJ_HLINE,0,TimeCurrent(),LOP);
        ObjectSet(instrument+"LOP",OBJPROP_COLOR,clrWhite);
      }
    /*if(ObjectFind(magic_str+instrument+"_HOP_up")<0) 
      {
        ObjectCreate(magic_str+instrument+"_HOP_up",OBJ_HLINE,0,TimeCurrent(),current_bid);
        ObjectSet(magic_str+instrument+"_HOP_up",OBJPROP_COLOR,clrGreen);
      }*/
    if(ObjectFind(instrument+"_HOP")<0)
      {
        ObjectCreate(instrument+"_HOP",OBJ_HLINE,0,TimeCurrent(),LOP+ADR_pts);
        ObjectSet(instrument+"_HOP",OBJPROP_COLOR,clrWhite);
      }
    if(LOP==-1) // this part is necessary in case periods_pivot_price ever returns 0
     {
       return -1;
     }
    else if(current_bid<LOP) // if the low of the range was surpassed // TODO: use compare_doubles()?
     {
       // since the bottom of the range was surpassed, you have to reset the LOP. You might as well take this opportunity to take the period into account.
       LOP=periods_pivot_price(BUYING_MODE);

       ObjectSet(instrument+"LOP",OBJPROP_PRICE1,LOP);
       ObjectSet(instrument+"_HOP",OBJPROP_PRICE1,LOP+ADR_pts);
       return -1;
     } 
    else if(current_bid-LOP>=ADR_pts) // if the pip move meets or exceed the ADR_Pips in points, return the current bid. Note: this will return true over and over again // TODO: use compare_doubles()?
     {
       // since the top of the range was surpassed and a pending order would be created, this is a good opportunity to update the LOP since you can't just leave it as the static value constantly
       LOP=periods_pivot_price(BUYING_MODE);

       ObjectSet(instrument+"LOP",OBJPROP_PRICE1,LOP);
       //ObjectSet(magic_str+instrument+"_HOP_up",OBJPROP_PRICE1,current_bid);
       ObjectSet(instrument+"_HOP",OBJPROP_PRICE1,LOP+ADR_pts);
       if(current_bid-LOP>=ADR_pts) // TODO: use compare_doubles()?
         {
          if(get_current_bid_instead) 
             {
                return current_bid; // check if it is actually true by taking the new calculation of Low Of Period into account
             }
          else 
             {
                double triggered_price=LOP+ADR_pts;
                return triggered_price;
             }
         }
       else return -1;
     }         
    else return -1;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double downtrend_ADR_threshold_price_met(bool get_current_bid_instead=false,int magic=-1)
  {
    static double HOP=0; // High Of Period
    double current_bid=MarketInfo(symbol,MODE_BID); // TODO: always make sure RefreshRates() was called before. In this case, it was called before running this function.
    string instrument=Symbol();
   
    if(HOP==0) HOP=periods_pivot_price(SELLING_MODE);
    if(ObjectFind(instrument+"_HOP")<0)
      {
        ObjectCreate(instrument+"_HOP",OBJ_HLINE,0,TimeCurrent(),HOP);
        ObjectSet(instrument+"_HOP",OBJPROP_COLOR,clrWhite);
      }
    /*if(ObjectFind(magic_str+instrument+"_LOP_down")<0) 
      {
        ObjectCreate(magic_str+instrument+"_LOP_down",OBJ_HLINE,0,TimeCurrent(),current_bid);
        ObjectSet(magic_str+instrument+"_LOP_down",OBJPROP_COLOR,clrRed);
      }*/
    if(ObjectFind(instrument+"LOP")<0)
      {
        ObjectCreate(instrument+"LOP",OBJ_HLINE,0,TimeCurrent(),HOP-ADR_pts);
        ObjectSet(instrument+"LOP",OBJPROP_COLOR,clrWhite);
      }
   if(HOP==-1) // this part is necessary in case periods_pivot_price ever returns 0
     {
       return -1;
     }
   else if(current_bid>HOP) // if the low of the range was surpassed // TODO: use compare_doubles()?
     {
       // since the bottom of the range was surpassed, you have to reset the LOP. You might as well take this opportunity to take the period into account.
       HOP=periods_pivot_price(SELLING_MODE);

       ObjectSet(instrument+"_HOP",OBJPROP_PRICE1,HOP);
       ObjectSet(instrument+"LOP",OBJPROP_PRICE1,HOP-ADR_pts);
       return -1;
     } 
   else if(HOP-current_bid>=ADR_pts) // if the pip move meets or exceed the ADR_Pips in points, return the current bid. Note: this will return true over and over again // TODO: use compare_doubles()?
     {
       // since the top of the range was surpassed and a pending order would be created, this is a good opportunity to update the LOP since you can't just leave it as the static value constantly
       HOP=periods_pivot_price(SELLING_MODE);

       ObjectSet(instrument+"_HOP",OBJPROP_PRICE1,HOP);
       //ObjectSet(magic_str+instrument+"_LOP_down",OBJPROP_PRICE1,current_bid);
       ObjectSet(instrument+"LOP",OBJPROP_PRICE1,HOP-ADR_pts);
       if(HOP-current_bid>=ADR_pts) // TODO: use compare_doubles()?
         {
           if(get_current_bid_instead) 
             {
               return current_bid; // check if it is actually true by taking the new calculation of Low Of Period into account
             }
           else 
             {
               double triggered_price=HOP-ADR_pts;
               return triggered_price;
             }
         }
       else return -1;
     }         
   else return -1;
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
bool modify(int ticket,double sl,double tp=-1,double entryPrice=-1,datetime expire=0,color a_color=clrNONE,int retries=3,int sleep_milisec=500) // TODO: should the defaults really be -1?
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
     Print(OrderSymbol()," , ",EA_name,", An order was attempted to be modified but it did not succeed. Last Error: (",IntegerToString(GetLastError(),0),"), Retry: ",IntegerToString(i,0),"/"+IntegerToString(retries));
     Alert(OrderSymbol()," , ",EA_name,", An order was attempted to be modified but it did not succeed. Check the Journal tab of the Navigator window for errors.");
        }
     }
   else
   {   
      Print(OrderSymbol()," , ",EA_name,", Modifying the order was not successfull. The ticket couldn't be selected.");
   }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool exit_order(int ticket,int max_slippage_pips,color a_color=clrNONE)
  {
   bool result=false;
   if(OrderSelect(ticket,SELECT_BY_TICKET))
     {
      if(OrderType()<=1) // if order type is an OP_BUY or OP_SELL (not a pending order). (OrderType() can be successfully called after a successful selection using OrderSelect())
        {
         result=OrderClose(ticket,OrderLots(),OrderClosePrice(),max_slippage_pips,a_color); // current order
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
bool try_to_exit_order(int ticket,int max_slippage_pips,color a_color=clrNONE,int retries=3,int sleep_milisec=500)
  {
   bool result=false;
   
   for(int i=0;i<retries;i++)
     {
      if(!IsConnected()) Print("The EA can't close ticket ",IntegerToString(ticket)," because there is no internet connection.");
      else if(!IsExpertEnabled()) Print("The EA can't close ticket ",IntegerToString(ticket)," because EAs are not enabled in the trading platform.");
      else if(IsTradeContextBusy()) Print("The EA can't close ticket ",IntegerToString(ticket)," because the trade context is busy.");
      else if(!IsTradeAllowed()) Print("The EA can't close ticket ",IntegerToString(ticket)," because the close order is not allowed in the trading platform.");
      else result=exit_order(ticket,max_slippage_pips,a_color);
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
// By default, if the type and magic number is not supplied it is set to -1 so the function exits all orders (including ones from different EAs). But, there is an option to specify the type of orders when calling the function.
void exit_all(int type=-1,int magic=-1) 
  {
   for(int i=OrdersTotal()-1;i>=0;i--) // it has to iterate through the array from the highest to lowest
     {
      if(OrderSelect(i,SELECT_BY_POS)) // if an open trade can be found
        {
         if((type==-1 || type==OrderType()) && (magic==-1 || magic==OrderMagicNumber()))
            try_to_exit_order(OrderTicket(),exiting_max_slippage_pips);
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// This is similar to the exit_all function except that it allows you to choose more sets  to close. It will iterate through all open trades and close them based on the order type and magic number
void exit_all_trades_set(int max_slippage_pips,ENUM_ORDER_SET type_needed=ORDER_SET_ALL,int magic=-1,int exit_seconds=0,datetime current_time=-1)  // magic==-1 means that all orders/trades will close (including ones managed by other running EAs)
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
              if((current_time-OrderOpenTime())<exit_seconds) break;  // TODO: be sure that this still can get the open time of the current selected ticket // TODO: is this actually working?
                
            switch(type_needed)
              {
               case ORDER_SET_BUY:
                  if(actual_type==OP_BUY) try_to_exit_order(ticket,max_slippage_pips);
                  break;
               case ORDER_SET_SELL:
                  if(actual_type==OP_SELL) try_to_exit_order(ticket,max_slippage_pips);
                  break;
               case ORDER_SET_BUY_LIMIT:
                  if(actual_type==OP_BUYLIMIT) try_to_exit_order(ticket,max_slippage_pips);
                  break;
               case ORDER_SET_SELL_LIMIT:
                  if(actual_type==OP_SELLLIMIT) try_to_exit_order(ticket,max_slippage_pips);
                  break;
               /*case ORDER_SET_BUY_STOP:
                  if(actual_type==OP_BUYSTOP) try_to_exit_order(ticket,max_slippage_pips);
                  break;
               case ORDER_SET_SELL_STOP:
                  if(actual_type==OP_SELLSTOP) try_to_exit_order(ticket,max_slippage_pips);
                  break;*/
               case ORDER_SET_LONG:
                  if(actual_type==OP_BUY || actual_type==OP_BUYLIMIT /*|| ordertype==OP_BUYSTOP*/)
                  try_to_exit_order(ticket,max_slippage_pips);
                  break;
               case ORDER_SET_SHORT:
                  if(actual_type==OP_SELL || actual_type==OP_SELLLIMIT /*|| ordertype==OP_SELLSTOP*/)
                  try_to_exit_order(ticket,max_slippage_pips);
                  break;
               case ORDER_SET_LIMIT:
                  if(actual_type==OP_BUYLIMIT || actual_type==OP_SELLLIMIT)
                  try_to_exit_order(ticket,max_slippage_pips);
                  break;
               /*case ORDER_SET_STOP:
                  if(actual_type==OP_BUYSTOP || actual_type==OP_SELLSTOP)
                  try_to_exit_order(ticket,max_slippage_pips);
                  break;*/
               case ORDER_SET_MARKET:
                  if(actual_type<=1) try_to_exit_order(ticket,max_slippage_pips);
                  break;
               case ORDER_SET_PENDING:
                  if(actual_type>1) try_to_exit_order(ticket,max_slippage_pips);
                  break;
               default: try_to_exit_order(ticket,max_slippage_pips); // this is the case where type==ORDER_SET_ALL falls into
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool acceptable_spread(string instrument,double _max_spread_percent,bool _based_on_raw_ADR=true,double spread_pts_provided=0,bool refresh_rates=false)
  {
   double _spread_pts=0;
   
   if(refresh_rates) RefreshRates();
   if(spread_pts_provided==0)
    {
     _spread_pts=NormalizeDouble(MarketInfo(instrument,MODE_SPREAD)/100,Digits); //  divide by 10? already normalized. I put this check here because the rates were just refereshed.
    }
   else
    {
      _spread_pts=spread_pts_provided;
    }
   if(_based_on_raw_ADR)
    {
      if(compare_doubles(_spread_pts,(((ADR_pts*change_ADR_percent)+ADR_pts)*_max_spread_percent),Digits)<=0) return true; // Keeps the EA from entering trades when the spread is too wide for market orders (but not pending orders). Note: It may never enter on exotic currencies (which is good automation).
    }
   else
    {
      if(compare_doubles(_spread_pts,NormalizeDouble((ADR_pts*_max_spread_percent),Digits),Digits)<=0) return true; // Keeps the EA from entering trades when the spread is too wide for market orders (but not pending orders). Note: It may never enter on exotic currencies (which is good automation).
    }
   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculate_avg_spread_yesterday(string instrument)
  {
    /*datetime new_server_day=-1;
    datetime end_server_day=-1;
    double spread_total=0;
    
    if(TimeDayOfWeek(iTime(symbol,PERIOD_D1,1))!=0) // if not Sunday, analyze yesterday
      {
        new_server_day=iTime(symbol,PERIOD_D1,1);
        end_server_day=iTime(symbol,PERIOD_D1,0)-(5*60);
      }    
    else // if Sunday, analyze the day before yesterday
      {
        new_server_day=iTime(symbol,PERIOD_D1,2);
        end_server_day=iTime(symbol,PERIOD_D1,1)-(5*60); // the start of the last bar of the specific day
      }
    
    int new_server_day_bar=iBarShift(instrument,PERIOD_M5,new_server_day,false);
    int end_server_day_bar=iBarShift(instrument,PERIOD_M5,end_server_day,false);
    
    for(int i=new_server_day_bar;i>=end_server_day_bar;i--) // 288 M5 bars in 24 hours
      {
        datetime bar_time=iTime(symbol,PERIOD_M5,i);
        // convert bar_time
        
        bool in_time_range=in_time_range(bar_time,start_time_hour,start_time_minute,end_time_hour,end_time_minute,gmt_hour_offset);
        if(in_time_range)
          {
            // TODO: you won't be able to get the average spread from the previous day because it is not possible. Try to code a spread history indicator and get it from there.
            double spread=NormalizeDouble(MarketInfo(instrument,MODE_SPREAD),Digits); // divide by 10
            spread_total+=spread;
          }
      }
    return NormalizeDouble(spread_total/(new_server_day_bar-end_server_day_bar),Digits); // return the average spread*/
    
    double avg_spread_yesterday=NormalizeDouble(MarketInfo(symbol,MODE_SPREAD)/100*point_multiplier,Digits); // this line is temporary until I find a way to get spread history
    Print("calculate_avg_spread_yesterday() returns: ",avg_spread_yesterday);
    return avg_spread_yesterday;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void try_to_enter_order(ENUM_ORDER_TYPE type,int magic,int max_slippage_pips)
  {
   double distance_pts;
   double periods_pivot_price;
   color arrow_color;
   
   if(pullback_percent==0 || pullback_percent==NULL) distance_pts=0;
   else distance_pts=NormalizeDouble((ADR_pts*pullback_percent)*point_multiplier,Digits);
   
   //Print("try_to_enter_order(): distance_pts: ",DoubleToString(distance_pts));
   
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
   
   RefreshRates(); // TODO: should you RefreshRates() here?
   double spread_pts=NormalizeDouble(MarketInfo(symbol,MODE_SPREAD)/100,Digits);
   double lots=calculate_lots(money_management,risk_percent_per_ADR,spread_pts);

   check_for_entry_errors (symbol,
                           type,
                           lots,
                           distance_pts, // the distance_pips you are sending to the function should always be positive
                           periods_pivot_price,
                           NormalizeDouble((ADR_pts*stoploss_percent)-distance_pts*point_multiplier,Digits),
                           NormalizeDouble((ADR_pts*takeprofit_percent)*point_multiplier,Digits),
                           max_slippage_pips,
                           NormalizeDouble(spread_pts*point_multiplier,Digits),
                           EA_name,
                           magic,
                           (int)(pending_order_expire*3600),
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
string generate_comment(int magic,double sl_pts, double tp_pts,double spread_pts) // TODO: Add more user parameter settings for the order to the message so they know what settings generated the results.
  {
    string comment;
    int divide_by=100; // TODO: do you need this in the calculations below?
    if(symbol=="USDJPY") divide_by=10;
    else divide_by=100;
    return comment=StringConcatenate("EA: ",EA_name,"Magic#: ",IntegerToString(magic),", CCY Pair: ",symbol," Requested TP: ",DoubleToStr(tp_pts)," Requested SL: ",DoubleToStr(sl_pts),"Spread slighly before order: ",DoubleToStr(spread_pts));
  }

int check_for_entry_errors(string instrument,int cmd,double lots,double _distance_pts,double periods_pivot_price,double sl_pts,double tp_pts,int max_slippage,double spread_points,string _EA_name=NULL,int magic=0,int expire=0,color a_clr=clrNONE,bool market=false,int retries=3,int sleep_milisec=500)
  {
   int ticket=0;
   for(int i=0;i<retries;i++)
     {
      if(IsStopped()) Print("The EA can't enter a trade because the EA was stopped.");
      else if(!IsConnected()) Print("The EA can't enter a trade because there is no internet connection.");
      else if(!IsExpertEnabled()) Print("The EA can't enter a trade because EAs are not enabled in trading platform.");
      else if(IsTradeContextBusy()) Print("The EA can't enter a trade because the trade context is busy.");
      else if(!IsTradeAllowed()) Print("The EA can't enter a trade because the trade is not allowed in the trading platform.");
      else ticket=send_and_get_order_ticket(instrument,cmd,lots,_distance_pts,periods_pivot_price,sl_pts,tp_pts,max_slippage,spread_points,_EA_name,magic,expire,a_clr,market);
      if(ticket>0) break;
      else
      { 
        // TODO: setup an email and SMS alert.
        Print(Symbol()," , ",EA_name,": An order was attempted but it did not succeed. If there are no errors here, market factors may not have met the code's requirements within the send_and_get_order_ticket function. Last Error:, (",IntegerToString(GetLastError(),0),"), Retry: "+IntegerToString(i,0),"/"+IntegerToString(retries));
        Alert(Symbol()," , ",EA_name,": An order was attempted but it did not succeed. Check the Journal tab of the Navigator window for errors.");
      }
      Sleep(sleep_milisec);
     }
   return ticket;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void generate_spread_not_acceptable_message(double spread_pts)
  {
    double percent_allows_trading=NormalizeDouble(((average_spread_yesterday-(ADR_pts*max_spread_percent))/ADR_pts)+max_spread_percent,3);
    string message=StringConcatenate (Symbol()," this signal to enter can't be sent because the current spread does not meet your max_spread_percent (",
                                      DoubleToStr(max_spread_percent,3),") of ADR criteria. The average spread yesterday was ",
                                      DoubleToStr(average_spread_yesterday,3),
                                      " but the current spread (",DoubleToStr(spread_pts,2),") is not acceptable. A max_spread_percent value above ",
                                      DoubleToStr(percent_allows_trading,3),
                                      " would have allowed the EA to make this trade.");
    
    Alert(message); 
    Print(message);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// the distanceFromCurrentPrice parameter is used to specify what type of order you would like to enter
int send_and_get_order_ticket(string instrument,int cmd,double lots,double _distance_pts,double periods_pivot_price,double sl_pts,double tp_pts,int max_slippage,double spread_pts,string _EA_name=NULL,int magic=0,int expire=0,color a_clr=clrNONE,bool market=false) // the "market" argument is to make this function compatible with brokers offering market execution. By default, it uses instant execution.
  {
   double entry_price=0; 
   double price_sl=0, price_tp=0;
   double min_distance_pts=MarketInfo(symbol,MODE_STOPLEVEL)/100*point_multiplier;
   int digits=(int)MarketInfo(symbol,MODE_DIGITS);
   datetime expire_time=0; // 0 means there is no expiration time for a pending order
   int order_type=-1; // -1 means there is no order because actual orders are >=0
   

   //Print("send_and_get_order_ticket(): tp_pts before adding spread_pts: ",DoubleToString(tp_pts)); 
   
   tp_pts+=spread_pts; // increase the take profit so the user can get the full pips of profit you wanted if the take profit price is hit
   
   //Print("send_and_get_order_ticket(): lots: ",DoubleToString(lots));
   //Print("send_and_get_order_ticket(): _distance_pts: ",DoubleToString(_distance_pts));   
   //Print("send_and_get_order_ticket(): min_distance_pts: ",DoubleToString(min_distance_pts));
   //Print("send_and_get_order_ticket(): current_price: ",DoubleToString(Bid)); 
   //Print("send_and_get_order_ticket(): periods_pivot_price: ",DoubleToString(periods_pivot_price));

   //Print("send_and_get_order_ticket(): max_slippage: ",IntegerToString(max_slippage));
   //Print("send_and_get_order_ticket(): spread_pts: ",DoubleToString(spread_pts)); 
   //Print("send_and_get_order_ticket(): tp_pts: ",DoubleToString(tp_pts)); 
   //Print("send_and_get_order_ticket(): magic: ",IntegerToString(magic));  
   
   if(cmd==OP_BUY) // logic for long trades
     {
      bool instant_exec=!market;
      if(_distance_pts>0) order_type=OP_BUYLIMIT;
      else if(_distance_pts==0) order_type=OP_BUY;
      else /*if(_distance_pts<0) order_type=OP_BUYSTOP*/ return 0;
      if(order_type==OP_BUYLIMIT /*|| order_type==OP_BUYSTOP*/)
        {
         if(periods_pivot_price<0) return 0;
         entry_price=(periods_pivot_price+ADR_pts)-_distance_pts+average_spread_yesterday /*(which should make it close to MODE_ASK which is similar to what the immediate buy order does)*/; // setting the entry_price this way prevents setting your limit and stop orders based on the current price (which would have caused inaccurate setting of prices)
         //Print("send_and_get_order_ticket(): periods_pivot_price-Bid: ",DoubleToString(periods_pivot_price-Bid));
         //Print("send_and_get_order_ticket(): ADR_pts: ",DoubleToString(ADR_pts));
         //Print("send_and_get_order_ticket(): average_spread_yesterday: ",DoubleToString(average_spread_yesterday));         
        }
      else if(order_type==OP_BUY)
        {
         if(acceptable_spread(instrument,max_spread_percent,based_on_raw_ADR,spread_pts,true))
          {
            entry_price=MarketInfo(instrument,MODE_ASK);// Keeps the EA from entering trades when the spread is too wide for market orders (but not pending orders). Note: It may never enter on exotic currencies (which is good automation).
            //Print("send_and_get_order_ticket(): entry_price: ",DoubleToString(entry_price));
          }
         else
          {
            generate_spread_not_acceptable_message(spread_pts);
            return 0;
          }
        }
      if(instant_exec) // if the user wants instant execution (in which the broker's system allows them to input sl and tp prices with the SendOrder)
        {
         if(sl_pts>0) 
          {
            if(compare_doubles(sl_pts,min_distance_pts,digits)==-1) price_sl=entry_price-min_distance_pts; 
            else price_sl=entry_price-sl_pts;
            //Print(price_sl,"=",entry_price,"-",sl_pts);

          }
         if(compare_doubles(tp_pts,spread_pts,digits)==1)
          {
            if(compare_doubles(tp_pts,min_distance_pts,digits)==-1) price_tp=entry_price+min_distance_pts;
            else price_tp=entry_price+tp_pts;
            //Print(price_tp,"=",entry_price,"+",tp_pts);
          }    
        }
     }
   else if(cmd==OP_SELL) // logic for short trades
     {
      bool instant_exec=!market;
      if(_distance_pts>0) order_type=OP_SELLLIMIT;
      else if(_distance_pts==0) order_type=OP_SELL;
      else /*if(_distance_pts<0) order_type=OP_SELLSTOP*/ return 0;
      if(order_type==OP_SELLLIMIT /*|| order_type==OP_SELLSTOP*/)
        {
         if(periods_pivot_price<0) return 0;
         entry_price=(periods_pivot_price-ADR_pts)+_distance_pts-average_spread_yesterday /*(which should make it close to MODE_BID which is similar to what the immediate buy order does*/; // setting the entry_price this way prevents setting your limit and stop orders based on the current price (which would have caused inaccurate setting of prices)
        }
      else if(order_type==OP_SELL)
        {
         if(acceptable_spread(instrument,max_spread_percent,based_on_raw_ADR,spread_pts,true)) 
          {
          entry_price=MarketInfo(instrument,MODE_BID); // Keeps the EA from entering trades when the spread is too wide for market orders (but not pending orders). Note: It may never enter on exotic currencies (which is good automation).
         // TODO: create an alert informing the user that the trade was not executed because the spread was too wide  
          }       
         else 
          {
            generate_spread_not_acceptable_message(spread_pts);
            return 0;
          }
        }
      if(instant_exec) // if the user wants instant execution (in which allows them to input the sl and tp prices)
        {
         if(sl_pts>0) 
          {
            if(compare_doubles(sl_pts,min_distance_pts,digits)==-1) price_sl=entry_price+min_distance_pts;
            else price_sl=entry_price+sl_pts;          
          }
         if(compare_doubles(tp_pts,spread_pts,digits)==1)
          {
            if(compare_doubles(tp_pts,min_distance_pts,digits)==-1) price_tp=entry_price-min_distance_pts; 
            else price_tp=entry_price-tp_pts; 
          }
        }
     }
   string generated_comment=generate_comment(magic,sl_pts,tp_pts,spread_pts);
   if(order_type<0) 
     return 0; // if there is no order
   else if(order_type==0 || order_type==1) 
     expire_time=0; // if it is NOT a pending order, set the expire_time to 0 because it cannot have an expire_time
   else if(expire>0) // if the user wants pending orders to expire
     expire_time=(datetime)MarketInfo(instrument,MODE_TIME)+expire; // expiration of the order = current time + expire time
   if(market) // If the user wants market execution (which does NOT allow them to input the sl and tp prices), this will calculate the stoploss and takeprofit AFTER the order to buy or sell is sent.
     {
      int ticket=OrderSend(instrument,order_type,lots,entry_price,max_slippage,0,0,generated_comment,magic,expire_time,a_clr);
      if(ticket>0) // if there is a valid ticket
        {
         if(OrderSelect(ticket,SELECT_BY_TICKET))
           {
            if(cmd==OP_BUY)
              {
               if(sl_pts>0) 
                {
                  if(compare_doubles(sl_pts,min_distance_pts,digits)==-1) price_sl=OrderOpenPrice()-min_distance_pts; 
                  else price_sl=OrderOpenPrice()-sl_pts;
                }
               if(compare_doubles(tp_pts,spread_pts,digits)==1)
                 {
                  if(compare_doubles(tp_pts,min_distance_pts,digits)==-1) price_sl=OrderOpenPrice()+min_distance_pts;                   
                  else price_tp=OrderOpenPrice()+tp_pts;
                 }
               uptrend_triggered=true;
               downtrend_triggered=false;
              }
            else if(cmd==OP_SELL)
              {
               if(sl_pts>0) 
                 {
                  if(compare_doubles(sl_pts,min_distance_pts,digits)==-1) price_sl=OrderOpenPrice()+min_distance_pts;
                  price_sl=OrderOpenPrice()+sl_pts;
                 }
               if(compare_doubles(tp_pts,spread_pts,digits)==1)
                 {
                  if(compare_doubles(tp_pts,min_distance_pts,digits)==-1) price_sl=OrderOpenPrice()-min_distance_pts; 
                  price_tp=OrderOpenPrice()-tp_pts;
                 }
               uptrend_triggered=false;
               downtrend_triggered=true;
              }
            bool result=modify(ticket,price_sl,price_tp);
           }
        }
      return ticket;
     }
   int ticket=OrderSend(instrument,order_type,lots,entry_price,max_slippage,price_sl,price_tp,generated_comment,magic,expire_time,a_clr);
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
double calculate_lots(ENUM_MM _money_management,double _risk_percent_per_ADR,double spread_pts)
  {
    double points=0;
    double _stoploss_percent=stoploss_percent;

    if(_money_management==MM_RISK_PERCENT_PER_ADR)
      points=NormalizeDouble(ADR_pts/*+spread_pts*/,Digits); // Increase the Average Daily (pip) Range by adding the average (pip) spread because it is additional pips at risk everytime a trade is entered. As a result, the lots that get calculated will be lower (which will reduce the risk).
    else if(ADR_pts>0 && _stoploss_percent>0)
      points=NormalizeDouble((ADR_pts*_stoploss_percent)/*+spread_pts*/,Digits); // it could be 0 if stoploss_percent is set to 0 
    else 
      points=NormalizeDouble(ADR_pts/*+spread_pts*/,Digits);

    double lots=get_lots(_money_management,
                        symbol,
                        lot_size, // the global variable
                        _risk_percent_per_ADR,
                        points/* /Point */,
                        mm1_risk_percent
                        /*,mm2_lots,
                        mm2_per,
                        mm3_risk,
                        mm4_risk*/);
   return lots;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// TODO: is it pips or points that the 5th parameter actually needs?
double get_lots(ENUM_MM method,string instrument,double lots,double _risk_percent_per_ADR,double pts,double risk_mm1_percent/*,double lots_mm2,double per_mm2,double risk_mm3,double risk_mm4*/)
  {
   double balance=AccountBalance();
   double tick_value=MarketInfo(instrument,MODE_TICKVALUE);
    
   switch(method)
     {
      case MM_RISK_PERCENT_PER_ADR:
         if(pts>0) lots=((balance*_risk_percent_per_ADR)/pts)/tick_value;
         break;
      case MM_RISK_PERCENT:
         if(pts>0) lots=((balance*risk_mm1_percent)/pts)/tick_value;
         break;
      /*case MM_FIXED_RATIO:
         lots=balance*lots_mm2/per_mm2;
         break;
      case MM_FIXED_RISK:
         if(pips>0) lots=(risk_mm3/tick_value)/pts;
         break;
      case MM_FIXED_RISK_PER_POINT:
         lots=risk_mm4/tick_value;
         break;*/
     }
   // get information from the broker and then Normalize the lots double
   double min_lot=MarketInfo(instrument,MODE_MINLOT);
   double max_lot=MarketInfo(instrument,MODE_MAXLOT);
   int lot_digits=(int) -MathLog10(MarketInfo(instrument,MODE_LOTSTEP)); // MathLog10 returns the logarithm of a number (in this case, the MODE_LOTSTEP) base 10. So, this finds out how many digits in the lot the broker accepts.
   lots=NormalizeDouble(lots/1000,lot_digits);
   // If the lots value is below or above the broker's MODE_MINLOT or MODE_MAXLOT, the lots will be change to one of those lot sizes. This is in order to prevent Error 131 - invalid trade volume
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
bool virtualstop_check_order(int ticket,double sl,double tp,int max_slippage)
  {
   if(ticket<=0) return true;
   if(!OrderSelect(ticket,SELECT_BY_TICKET)) return false;
   
   int digits=(int) MarketInfo(OrderSymbol(),MODE_DIGITS);
   bool result=true;
   if(OrderType()==OP_BUY)
     {
      double virtual_stoploss=OrderOpenPrice()-sl;
      double virtual_takeprofit=OrderOpenPrice()+tp;
      if((sl>0 && compare_doubles(OrderClosePrice(),virtual_stoploss,digits)<=0) || 
         (tp>0 && compare_doubles(OrderClosePrice(),virtual_takeprofit,digits)>=0))
        {
         result=exit_order(ticket,max_slippage);
        }
     }
   else if(OrderType()==OP_SELL)
     {
      double virtual_stoploss=OrderOpenPrice()+sl;
      double virtual_takeprofit=OrderOpenPrice()-tp;
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
// Checking and moving trailing stop while the order is open
bool trailingstop_check_order(int ticket,double trail_pips,double threshold,double step)
  {
   if(ticket<=0) return true;
   if(!OrderSelect(ticket,SELECT_BY_TICKET)) return false;
   
   int digits=(int) MarketInfo(OrderSymbol(),MODE_DIGITS);
   bool result=true;
   
   if(OrderType()==OP_BUY)
     {
      double new_moving_sl=OrderClosePrice()-trail_pips; // the current price - the trail in pips
      double threshold_activation_price=OrderOpenPrice()+threshold;
      double activation_sl=threshold_activation_price-trail_pips;
      double step_in_pts=new_moving_sl-OrderStopLoss(); // keeping track of the distance between the potential stoploss and the current stoploss
      if(OrderStopLoss()==0|| compare_doubles(activation_sl,OrderStopLoss(),digits)==1)
        {
         if(compare_doubles(OrderClosePrice(),threshold_activation_price,digits)>=0) // if price met the threshold, move the stoploss
            result=modify(ticket,activation_sl);
        }
      else if(compare_doubles(step_in_pts,step,digits)>=0) // if price met the step, move the stoploss
        {
         result=modify(ticket,new_moving_sl);
        }
     }
   else if(OrderType()==OP_SELL)
     {
      double new_moving_sl=OrderClosePrice()+trail_pips;
      double threshold_activation_price=OrderOpenPrice()-threshold;
      double activation_sl=threshold_activation_price+trail_pips;
      double step_in_pts=OrderStopLoss()-new_moving_sl;
      if(OrderStopLoss()==0|| compare_doubles(activation_sl,OrderStopLoss(),digits)==-1)
        {
         if(compare_doubles(OrderClosePrice(),threshold_activation_price,digits)<=0)
            result=modify(ticket,activation_sl);
        }
      else if(compare_doubles(step_in_pts,step,digits)>=0)
        {
         result=modify(ticket,new_moving_sl);
        }
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void trailingstop_check_all_orders(double trail,double threshold,double step,int magic=-1)
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
// use this function  in case you do not want the broker to know where your stop is
void virtualstop_check_all_orders(double sl,double tp,int magic=-1,int max_slippage=50)
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
bool breakeven_check_order(int ticket,double threshold_pips,double plus_pips) 
  {
   if(ticket<=0) return true; // if it is not a valid ticket
   if(!OrderSelect(ticket,SELECT_BY_TICKET)) return false; // if there is no ticket, it cannot be process so return false
   int digits=(int)MarketInfo(OrderSymbol(),MODE_DIGITS); // how many digit broker
   double point=MarketInfo(symbol,MODE_POINT);
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
void breakeven_check_all_orders(double threshold,double plus,int magic=-1) // a -1 magic number means the there is no magic number in this order or EA
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
int count_similar_orders(ENUM_DIRECTIONAL_MODE mode) // With pool, you can define whether to count current orders (MODE_TRADES) or closed and cancelled orders (MODE_HISTORY).
  {
    int count=0;
    string this_instrument=OrderSymbol();
    string this_first_ccy=StringSubstr(this_instrument,0,3);
    string this_second_ccy=StringSubstr(this_instrument,3,3);
   
    for(int i=OrdersTotal()-1;i>=0;i--) // You have to start iterating from the lower part (or 0) of the order array because the newest trades get sent to the start. Interate through the index from a not excessive index position (the middle of an index) to OrdersTotal()-1 // the oldest order in the list has index position 0
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) // Problem: if the pool is MODE_HISTORY, that can be a lot of data to search. So make sure you calculated a not-excessive pools_end_index (the oldest order that is acceptable).
        {
        int other_trades_type=OrderType();
        if(other_trades_type>1) // if it is a pending order, break
          break;
        else
          {
            string other_instrument=OrderSymbol();
            string other_first_ccy=StringSubstr(other_instrument,0,3);
            string other_second_ccy=StringSubstr(other_instrument,3,3);           
            switch(mode)
              {
               case BUYING_MODE:
                  if((other_trades_type==OP_BUY && this_first_ccy==other_first_ccy) || (other_trades_type==OP_SELL && this_first_ccy==other_second_ccy)) count++;
                  break;
               case SELLING_MODE:
                  if((other_trades_type==OP_SELL && this_first_ccy==other_first_ccy) || (other_trades_type==OP_BUY && this_first_ccy==other_second_ccy)) count++;
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
void cleanup_all_pending_orders(int max_ccy_directional_trades) 
  { 
    for(int i=OrdersTotal()-1;i>=0;i--) // You have to start iterating from the lower part (or 0) of the order array because the newest trades get sent to the start. Interate through the index from a not excessive index position (the middle of an index) to OrdersTotal()-1 // the oldest order in the list has index position 0
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) // Problem: if the pool is MODE_HISTORY, that can be a lot of data to search. So make sure you calculated a not-excessive pools_end_index (the oldest order that is acceptable).
        {
        int market_orders_direction=OrderType();
        if(market_orders_direction>1) // if it is a pending order
          break;
        else
          {
            string market_orders_symbol=OrderSymbol();
            string market_orders_1st_ccy=StringSubstr(market_orders_symbol,0,3);
            string market_orders_2nd_ccy=StringSubstr(market_orders_symbol,3,3);
            for(int j=OrdersTotal()-1;j>=0;j--)
              {
                if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)) // Problem: if the pool is MODE_HISTORY, that can be a lot of data to search. So make sure you calculated a not-excessive pools_end_index (the oldest order that is acceptable).
                  {
                    int pending_orders_direction=OrderType();
                    if(pending_orders_direction<=1) // if it is a market order
                      break;
                    else
                      {
                        int pending_order=OrderTicket();
                        string pending_orders_symbol=OrderSymbol();
                        string pending_orders_1st_ccy=StringSubstr(pending_orders_symbol,0,3);
                        string pending_orders_2nd_ccy=StringSubstr(pending_orders_symbol,3,3);             
                        
                        if(market_orders_direction==OP_BUY && pending_orders_direction==OP_BUYLIMIT)
                          {
                            if(market_orders_1st_ccy==pending_orders_1st_ccy) try_to_exit_order(pending_order,exiting_max_slippage_pips); // TODO: get rid of the requirement for the slippage parameter
                            if(market_orders_2nd_ccy==pending_orders_2nd_ccy) try_to_exit_order(pending_order,exiting_max_slippage_pips); // TODO: get rid of the requirement for the slippage parameter                      
                          }
                        else if(market_orders_direction==OP_SELL && pending_orders_direction==OP_SELLLIMIT)
                          {
                            if(market_orders_1st_ccy==pending_orders_1st_ccy) try_to_exit_order(pending_order,exiting_max_slippage_pips); // TODO: get rid of the requirement for the slippage parameter
                            if(market_orders_2nd_ccy==pending_orders_2nd_ccy) try_to_exit_order(pending_order,exiting_max_slippage_pips); // TODO: get rid of the requirement for the slippage parameter                                               
                          }
                        else if(market_orders_direction==OP_BUY && pending_orders_direction==OP_SELLLIMIT)
                          {
                            if(market_orders_1st_ccy==pending_orders_2nd_ccy) try_to_exit_order(pending_order,exiting_max_slippage_pips); // TODO: get rid of the requirement for the slippage parameter
                            if(market_orders_2nd_ccy==pending_orders_1st_ccy) try_to_exit_order(pending_order,exiting_max_slippage_pips); // TODO: get rid of the requirement for the slippage parameter 
                          }
                        else if(market_orders_direction==OP_SELL && pending_orders_direction==OP_BUYLIMIT)
                          {
                            if(market_orders_1st_ccy==pending_orders_2nd_ccy) try_to_exit_order(pending_order,exiting_max_slippage_pips); // TODO: get rid of the requirement for the slippage parameter
                            if(market_orders_2nd_ccy==pending_orders_1st_ccy) try_to_exit_order(pending_order,exiting_max_slippage_pips); // TODO: get rid of the requirement for the slippage parameter 
                          }
                    }
                  }
              }  
          }
        }
      } 
  }
  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void cleanup_pending_orders() // deletes pending orders where the single currency of the market order would be the same direction of the single currency in the pending order
  { 
    static int last_trades_count=0;
    int trades_count=count_orders(ORDER_SET_MARKET,-1,MODE_TRADES,OrdersTotal()-1);
    
    if(last_trades_count<trades_count) // every time a limit order gets triggered and becomes a market order
      {
        int market_trades_direction;
        do
          {
            int i=0; 
            OrderSelect(i,SELECT_BY_POS,MODE_TRADES); // select the most recent market order in the index     
            market_trades_direction=OrderType();
            i++;
          }
        while(market_trades_direction>1 && !IsStopped()); // select the morst recent market order in the index
     
        string market_trades_symbol=OrderSymbol();
        string market_trades_1st_ccy=StringSubstr(market_trades_symbol,0,3);
        string market_trades_2nd_ccy=StringSubstr(market_trades_symbol,3,3);
        
        for(int j=OrdersTotal()-1;j>=0;j--)
          {
            if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES))
              {
                int pending_orders_direction=OrderType();
                if(pending_orders_direction<=1) // if it is a market order
                  break;
                else
                  {
                    int pending_order=OrderTicket();
                    string pending_orders_symbol=OrderSymbol();
                    string pending_orders_1st_ccy=StringSubstr(pending_orders_symbol,0,3);
                    string pending_orders_2nd_ccy=StringSubstr(pending_orders_symbol,3,3);             
                    
                    if(market_trades_direction==OP_BUY && pending_orders_direction==OP_BUYLIMIT)
                      {
                        if(market_trades_1st_ccy==pending_orders_1st_ccy) 
                          {
                            try_to_exit_order(pending_order,exiting_max_slippage_pips); // TODO: get rid of the requirement for the slippage parameter
                            last_trades_count=trades_count;
                          }
                        if(market_trades_2nd_ccy==pending_orders_2nd_ccy) 
                          {
                            try_to_exit_order(pending_order,exiting_max_slippage_pips); // TODO: get rid of the requirement for the slippage parameter  
                            last_trades_count=trades_count;      
                          }              
                      }
                    else if(market_trades_direction==OP_SELL && pending_orders_direction==OP_SELLLIMIT)
                      {
                        if(market_trades_1st_ccy==pending_orders_1st_ccy)
                          {
                            try_to_exit_order(pending_order,exiting_max_slippage_pips); // TODO: get rid of the requirement for the slippage parameter
                            last_trades_count=trades_count;
                          }
                        if(market_trades_2nd_ccy==pending_orders_2nd_ccy)
                          {
                            try_to_exit_order(pending_order,exiting_max_slippage_pips); // TODO: get rid of the requirement for the slippage parameter    
                            last_trades_count=trades_count;
                          }                                           
                      }
                    else if(market_trades_direction==OP_BUY && pending_orders_direction==OP_SELLLIMIT)
                      {
                        if(market_trades_1st_ccy==pending_orders_2nd_ccy) 
                          {
                            try_to_exit_order(pending_order,exiting_max_slippage_pips); // TODO: get rid of the requirement for the slippage parameter
                            last_trades_count=trades_count;
                          }
                        if(market_trades_2nd_ccy==pending_orders_1st_ccy) 
                          {
                            try_to_exit_order(pending_order,exiting_max_slippage_pips); // TODO: get rid of the requirement for the slippage parameter 
                            last_trades_count=trades_count;
                          }
                      }
                    else if(market_trades_direction==OP_SELL && pending_orders_direction==OP_BUYLIMIT)
                      {
                        if(market_trades_1st_ccy==pending_orders_2nd_ccy) 
                          {
                            try_to_exit_order(pending_order,exiting_max_slippage_pips); // TODO: get rid of the requirement for the slippage parameter
                            last_trades_count=trades_count;
                          }
                        if(market_trades_2nd_ccy==pending_orders_1st_ccy) 
                          {
                            try_to_exit_order(pending_order,exiting_max_slippage_pips); // TODO: get rid of the requirement for the slippage parameter
                            last_trades_count=trades_count;
                          }
                      }
                  }
              }
          }  
      }
  }

  