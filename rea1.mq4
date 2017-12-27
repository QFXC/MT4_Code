//+------------------------------------------------------------------+
//|                                            Relativity_EA_V01.mq4 |
//|                                                 Quant FX Capital |
//|                                   https://www.quantfxcapital.com |
//+------------------------------------------------------------------+
#property copyright "Quant FX Capital"
#property link      "https://www.quantfxcapital.com"
#property version   "1.06"
#property strict
// TODO: When strategy testing, make sure you have all the M5, H1, D1, and W1 data because it is reference in the code.
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
/*enum ENUM_TIME_FRAMES // TODO: these are not being used yet
  {
   M5=0,
   D1=1,
   W1=2
  };*/
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
enum ENUM_DIRECTION_BIAS  // since ENUM_ORDER_TYPE is not enough, this enum was created to be able to use neutral and void signals
  {
   DIRECTION_BIAS_IGNORE=-2, // ignore the current filter and move on to the next one
   DIRECTION_BIAS_VOID=-1, // exit all trades
   DIRECTION_BIAS_NEUTRAL=0, // do not buy, sell or exit any trades
   DIRECTION_BIAS_BUY=1,
   DIRECTION_BIAS_SELL=2
   
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
  static bool   ready=false, in_time_range=false;
// timeframe changes
  bool          is_new_M5_bar,is_new_custom_D1_bar,is_new_custom_W1_bar;
  /*input*/ bool wait_next_M5_on_load=false; //wait_next_M5_on_load: This setting currently affects all bars (including D1) so do not set it to true unless code changes are made. // When you load the EA, should it wait for the next bar to load before giving the EA the ability to enter a trade or calculate ADR?
  
// general settings
	//string        symbol=NULL; // TODO: finish changing the code to get rid of this global variable
  /*input*/ bool auto_adjust_broker_digits=true;
  int           point_multiplier;
	input bool    market_exec=true;                 //market_exec: False means that it is instant execution rather than market execution. Not all brokers offer market execution. The rule of thumb is to never set it as instant execution if the broker only provides market execution.
  int           retries=1; // TODO: eventually get rid of this global variable
  static int    EA_1_magic_num; // An EA can only have one magic number. Used to identify the EA that is managing the order. TODO: see if it can auto generate the magic number every time the EA is loaded on the chart.
  static bool   uptrend=false, downtrend=false;
  static bool   uptrend_trade_happened_last=false, downtrend_trade_happened_last=false;
  static double average_spread_yesterday=0;
	
	input bool    reverse_trade_direction=false;
	//input bool  only_enter_on_new_bar=false; // Should you only enter trades when a new bar begins?
	/*input*/ bool    exit_opposite_signal=false; //false exit_opposite_signal: Should the EA exit trades when there is a signal in the opposite direction?
  //bool        long_allowed=true; //true Are long trades allowed?
	//bool        short_allowed=true; //true Are short trades allowed?
	
	input string  space_1="----------------------------------------------------------------------------------------";
	
	input bool        filter_over_extended_trends=true;   //filter_over_extended_trends: //TODO: test that this filter works
	/*input*/ int     max_directional_trades_at_once=1;   //1 max_directional_trades_at_once: How many trades can the EA enter at the same time in the one direction on the current chart? (If 1, a long and short trade (2 trades) can be opened at the same time.)input int max_num_EAs_at_once=28; // What is the maximum number of EAs you will run on the same instance of a platform at the same time?
	/*input*/ int     max_trades_within_x_hours=1;        //1 max_trades_within_x_hours: 0-x days (x depends on the setting of the Account History tab of the terminal). // How many trades are allowed to be opened (even if they are closed now) within the last x_hours?
	/*input*/ double  x_hours=3;                          //3 x_hours: Any whole or fraction of an hour.
	/*input*/ int     max_directional_trades_each_day=1;  //1 max_directional_trades_each_day: How many trades are allowed to be opened (even if they are close now) after the start of each current day?
  input int         moving_avg_period=0;
  
  input string  space_2="----------------------------------------------------------------------------------------";
  
// time filters - only allow EA to enter trades between a range of time in a day
	/*input*/ int     gmt_hour_offset=0;                  //0 gmt_hour_offset: -2 if using Gain Capital and 1 of using FXDD. The value of 0 refers to the time zone used by the broker (seen as 0:00 on the chart). Adjust this offset hour value if the broker's 0:00 server time is not equal to when the time the NY session ends their trading day.
	input int     start_time_hour=0;                  //0 start_time_hour: 0-23
	input int     start_time_minute=0;                //0 start_time_minute: 0-59
	input int     end_time_hour=22;                   //22 end_time_hour: 0-23
	input int     end_time_minute=55;                 //55 end_time_minute: 0-59

	/*input*/ bool    exit_trades_EOD=false;              //false exit_trades_EOD
  /*input*/ int     exit_time_hour=23;                  //23 exit_time_hour: should be before the trading range start_time and after trading range end_time
  /*input*/ int     exit_time_minute=0;                 //0 exit_time_minute: 0-59
	
	input bool    trade_friday=true;                  //true trade_friday:
	input int     fri_end_time_hour=13;               //11 fri_end_time_hour: 0-23
	input int     fri_end_time_minute=0;             //30 fri_end_time_minute: 0-59
	
  input bool    exit_before_friday_close=true;      //true exit_before_friday_close
  input int     fri_exit_time_hour=22;              //22 fri_exit_time_hour
  input int     fri_exit_time_min=0;                //0 fri_exit_time_min
  
  input string  space_3="----------------------------------------------------------------------------------------";
  
// enter_order
  /*input*/ ENUM_SIGNAL_SET SIGNAL_SET=SIGNAL_SET_1; //SIGNAL_SET: Which signal set would you like to test? (the details of each signal set are found in the signal_entry function)
  // TODO: make sure you have coded for the scenerios when each of these is set to 0
	input double  retracement_percent=.38;            //retracement_percent: Must be positive.
	input double  pullback_percent=0.3;               //.3 pullback_percent:  Must be positive. If you want a buy or sell limit order, it must be positive.
	input double  takeprofit_percent=.8;              //.8 takeprofit_percent: Must be a positive number. (What % of ADR should you tarket?)
  double        stoploss_percent=1.0;               //1 stoploss_percent: Must be a positive number.
  input bool    prevent_ultrawide_stoploss=false;
	/*input*/ double max_spread_percent=.15;           //.1 max_spread_percent: Must be positive. What percent of ADR should the spread be less than? (Only for immediate orders and not pending.)
	/*input*/ bool based_on_raw_ADR=true;             //true based_on_raw_ADR: Should the max_spread_percent be calculated from the raw ADR?

// virtual stoploss variables
	int           virtual_sl=0; //0 TODO: Change to a percent of ADR
	int           virtual_tp=0; //0 TODO: Change to a percent of ADR
	
// breakeven variables
	input double  breakeven_threshold_percent=.8;      //.8 breakeven_threshold_percent: % of takeprofit before setting the stop to breakeven.
	input double  breakeven_plus_percent=-.5;          //-.5 breakeven_plus_percent: % of takeprofit above breakeven. Allows you to move the stoploss +/- from the entry price where 0 is breakeven, <0 loss zone, and >0 profit zone
	
// trailing stop variables
	input double  trail_threshold_percent=.5;          //.2 trail_threshold_percent: % of takeprofit before activating the trailing stop.
	input double  trail_step_percent=.1;               //.1 trail_step_percent: The % of takeprofit to set the minimum difference between the proposed new value of the stoploss to the current stoploss price
	input bool    same_stoploss_distance=false;       //false same_stoploss_distance: Use the same stoploss pips that the trade already had? If false, use the ADR as the stoploss.
	
	/*input*/ int entering_max_slippage_pips=50;       //5 entering_max_slippage_pips: Must be in whole number. // TODO: For 3 and 5 digit brokers, is 50 equivalent to 5 pips?
//input int unfavorable_slippage=5;
//exit_order
	/*input*/ int exiting_max_slippage_pips=50;       //50 exiting_max_slippage_pips: Must be in whole number. // TODO: For 3 and 5 digit brokers, is 50 equivalent to 5 pips?
	
	/*input*/ double  active_order_expire=0;              //0 active_order_expire: Any hours or fractions of hour(s). How many hours can a trade be on that hasn't hit stoploss or takeprofit?
	input double  pending_order_expire=6;             //6 pending_order_expire: Any hours or fractions of hour(s). In how many hours do you want your pending orders to expire?
	
  input string  space_4="----------------------------------------------------------------------------------------";
  
//calculate_lots/mm variables
	ENUM_MM       money_management=MM_RISK_PERCENT_PER_ADR;
	input bool    compound_balance=false;
	input double  risk_percent_per_range=0.03;          //.03 risk_percent_per_range: percent risked when using the MM_RISK_PER_ADR_PERCENT money management calculations. Any amount of digits after the decimal point. Note: This is not the percent of your balance you will be risking.
	double        mm1_risk_percent=0.02;              //mm1_risk_percent: percent risked when using the MM_RISK_PERCENT money management calculations
   // these variables will not be used with the MM_RISK_PERCENT money management strategy
	double        lot_size=0.0;
	/*double      mm2_lots=0.1;
	double        mm2_per=1000;
	double        mm3_risk=50;
	double        mm4_risk=50;*/
	
  input string  space_5="----------------------------------------------------------------------------------------";
  
// Market Trends
  input double  H1s_to_roll=11;                     //11 H1s_to_roll: Only divisible by .5 // How many hours should you roll to determine a short term market trend?
  input double  max_weekend_gap_percent=.15;        //.15 max_weekend_gap_percent: What is the maximum weekend gap (as a percent of ADR) for H1s_to_roll to not take the previous week into account?
  input bool    include_last_week=true;             //true include_last_week: Should the EA take Friday's moves into account when starting to determine length of the current move?
  //input bool    include_yesterday=true;           //TODO: Work on this
  static double ADR_pts;
  //static double RANGE_pts;
  static double HOP_price;
  static double LOP_price;
  static int    moves_start_bar;

  input string  space_7="----------------------------------------------------------------------------------------";
// ADR()
  /*input*/ int num_ADR_months=2;                   //2 num_ADR_months: How months back should you use to calculate the average ADR? (Divisible by 1)
  input double  change_ADR_percent=.3;              //.3 change_ADR_percent: this can be a 0, negative, or positive decimal or whole number. 
// TODO: make sure you have coded for the scenerios when each of these is set to 0
  input double  above_ADR_outlier_percent=1.5;      //1.5 above_ADR_outlier_percent: Can be any decimal with two numbers after the decimal point or a whole number. // How much should the ADR be surpassed in a day for it to be neglected from the average calculation?
  input double  below_ADR_outlier_percent=.5;       //.5 below_ADR_outlier_percent: Can be any decimal with two numbers after the decimal point or a whole number. // How much should the ADR be under in a day for it to be neglected from the average calculation?

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
   return OnInit_Relativity_EA_1(SIGNAL_SET,Symbol());
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit_Relativity_EA_1(ENUM_SIGNAL_SET signal_set,string instrument)
  {
    EventSetTimer(60);
    get_point_multiplier(instrument);
    get_changed_ADR_pts(H1s_to_roll,below_ADR_outlier_percent,above_ADR_outlier_percent,change_ADR_percent,instrument);
  
    double tick_value=MarketInfo(instrument,MODE_TICKVALUE);
    double point=MarketInfo(instrument,MODE_POINT);
    double spread=MarketInfo(instrument,MODE_SPREAD);
    double bid_price=MarketInfo(instrument,MODE_BID);
    double min_distance_pips=MarketInfo(instrument,MODE_STOPLEVEL);
    double min_lot=MarketInfo(instrument,MODE_MINLOT);
    double max_lot=MarketInfo(instrument,MODE_MAXLOT);
    int lot_digits=(int) -MathLog10(MarketInfo(instrument,MODE_LOTSTEP));
    int lot_step=(int)(MarketInfo(instrument,MODE_LOTSTEP));
    int digits=(int)MarketInfo(instrument,MODE_DIGITS);
    datetime current_bar_open_time=iTime(instrument,PERIOD_M5,0);        
    datetime current_time=(datetime)MarketInfo(instrument,MODE_TIME);
    int trade_allowed=(int)MarketInfo(instrument,MODE_TRADEALLOWED);
    double one_lot_initial_margin=MarketInfo(instrument,MODE_MARGININIT);
    double margin_to_mainain_open_orders=MarketInfo(instrument,MODE_MARGINMAINTENANCE);
    double hedged_margin=MarketInfo(instrument,MODE_MARGINHEDGED);
    double margin_required=MarketInfo(instrument,MODE_MARGINREQUIRED);
    double freeze_level_pts=MarketInfo(instrument,MODE_FREEZELEVEL);
    string current_chart=Symbol();

    Print("trade_allowed: ",trade_allowed);
    Print("one_lot_initial_margin: ",DoubleToStr(one_lot_initial_margin));
    Print("margin_to_maintain_open_orders: ",DoubleToStr(margin_to_mainain_open_orders));
    Print("hedged_margin: ",DoubleToStr(hedged_margin));
    Print("margin_required: ",DoubleToStr(margin_required));
    Print("freeze_level_pts: ",DoubleToStr(freeze_level_pts));
    Print("tick_value: ",DoubleToStr(tick_value));
    Print("Point: ",DoubleToStr(point));
    Print("spread before the function calls: ",DoubleToStr(spread));
    Print("spread before the function calls * point: ",DoubleToStr(spread*point));
    Print("spread before the function calls * point * point_multiplier: ",DoubleToStr(spread*point*point_multiplier));
    Print("ADR_pts: ",DoubleToStr(ADR_pts)); 
    Print("bid_price: ",DoubleToStr(bid_price));
    Print("min_distance_pips: ",DoubleToStr(min_distance_pips));
    Print("min_distance_pips*point: ",DoubleToStr(min_distance_pips*point));
    Print("min_distance_pips*point*point_multiplier: ",DoubleToStr(min_distance_pips*point*point_multiplier));
    Print("min_lot: ",DoubleToStr(min_lot)," .01=micro lots, .1=mini lots, 1=standard lots");
    Print("max_lot: ",DoubleToStr(max_lot));
    Print("lot_digits: ",IntegerToString(lot_digits)," after the decimal point.");
    Print("lot_step: ",lot_step);    
    Print("broker digits: ",IntegerToString(digits)," after the decimal point.");
    Print("current time: ",TimeToString(current_time));
    Print("current bar open time: ",TimeToString(current_bar_open_time));
    Print("current_chart: ",current_chart);
      // TODO: check if the broker has Sunday's as a server time, and, if not, block all the code you wrote to count Sunday's from running
      
      
    EA_1_magic_num=generate_magic_num(WindowExpertName(),signal_set);
    bool input_variables_valid=all_user_input_variables_valid();
    
    int range_start_time=(start_time_hour*3600)+(start_time_minute*60);
    int range_end_time=(end_time_hour*3600)+(end_time_minute*60);
    int exit_time=(exit_time_hour*3600)+(exit_time_minute*60);

     // Print("The EA will not work properly. The input variables max_trades_in_direction, max_num_EAs_at_once, and max_trades_within_x_hours can't be 0 or negative.");  
    Print(instrument,"'s Magic Number: ",IntegerToString(EA_1_magic_num));
    if(exit_time>range_start_time && exit_time<range_end_time && !input_variables_valid)
      {
        Print("The initialization of the EA failed. Make sure that the trade exit_time_hour and exit_time_minute combination does not fall within the trading range start and end times or else there will be trouble!");
        Alert("The initialization of the EA failed. Make sure that the trade exit_time_hour and exit_time_minute combination does not fall within the trading range start and end times or else there will be trouble!");
        return(INIT_FAILED);
      }
    else if(generate_magic_num(instrument,signal_set)<=0)
      {
        Print("The initialization of the EA failed. The magic number (",EA_1_magic_num,") is not a valid magic number for the Expert Advisor (EA). Without one, the EA will not run correctly. Get a MQL4 programmer check the code to find out why.");
        Alert("The initialization of the EA failed. The magic number (",EA_1_magic_num,") is not a valid magic number for the Expert Advisor (EA). Without one, the EA will not run correctly. Get a MQL4 programmer check the code to find out why.");
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

   Print("If there are no errors, then the ",WindowExpertName()," EA for ",Symbol()," has been successfully deinitialized.");
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
//| Expert tick function    s                                         |
//+------------------------------------------------------------------+
void OnTimer()
  {
   string instrument=Symbol();
   datetime current_time=(datetime)MarketInfo(instrument,MODE_TIME);
   int exit_signal=DIRECTION_BIAS_NEUTRAL, exit_signal_2=DIRECTION_BIAS_NEUTRAL; // 0
   int _exiting_max_slippage=exiting_max_slippage_pips;
   bool Relativity_EA_2_on=false;
   bool answer=false;
   bool is_new_H1_bar;
   
   is_new_M5_bar=is_new_M5_bar(wait_next_M5_on_load);
   if(is_new_M5_bar) is_new_H1_bar=is_new_H1_bar();
   if(is_new_H1_bar) is_new_custom_D1_bar=is_new_custom_D1_bar();
   if(is_new_custom_D1_bar) is_new_custom_W1_bar=is_new_custom_W1_bar();
   
   answer=Relativity_EA_ran(instrument,EA_1_magic_num,current_time,exit_signal,exit_signal_2,_exiting_max_slippage); // TODO: test by typing "USDJPYpro" as a replacement to instrument
   if(answer && Relativity_EA_2_on) 
     {
       answer=Relativity_EA_ran("EURUSDpro",EA_1_magic_num,current_time,exit_signal,exit_signal_2,_exiting_max_slippage);
     }
  }
void OnTick()
  {
   cleanup_risky_pending_orders();
   OnTimer();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool Relativity_EA_ran(string instrument,int magic,datetime current_time,int exit_signal,int exit_signal_2,int _exiting_max_slippage)
  {
   string current_chart=Symbol();
   bool current_chart_matches=(current_chart==instrument);
   
   if(ObjectFind(current_chart+"_LOP_price")<0)
      {
        ObjectCreate(current_chart+"_LOP_price",OBJ_HLINE,0,current_time,LOP_price);
        ObjectSet(current_chart+"_LOP_price",OBJPROP_COLOR,clrBlue);
        ObjectSet(current_chart+"_LOP_price",OBJPROP_STYLE,STYLE_DOT);
      }
   if(ObjectFind(current_chart+"_HOP_price")<0)
      {
        ObjectCreate(current_chart+"_HOP_price",OBJ_HLINE,0,current_time,HOP_price);
        ObjectSet(current_chart+"_HOP_price",OBJPROP_COLOR,clrBlue);
        ObjectSet(current_chart+"_HOP_price",OBJPROP_STYLE,STYLE_DOT);
      }
   ObjectSet(current_chart+"_LOP_price",OBJPROP_PRICE1,LOP_price); 
   ObjectSet(current_chart+"_LOP_price",OBJPROP_TIME1,current_time); 
   ObjectSet(current_chart+"_HOP_price",OBJPROP_PRICE1,HOP_price); 
   ObjectSet(current_chart+"_HOP_price",OBJPROP_TIME1,current_time);
   

   /*exit_signal=signal_exit(instrument,SIGNAL_SET); // The exit signal should be made the priority and doesn't require in_time_range or adr_generated to be true

   if(exit_signal==DIRECTION_BIAS_VOID)       exit_all_trades_set(_exiting_max_slippage,ORDER_SET_ALL,magic); // close all pending and orders for the specific EA's orders. Don't do validation to see if there is an EA_magic_num because the EA should try to exit even if for some reason there is none.
   else if(exit_signal==DIRECTION_BIAS_BUY)   exit_all_trades_set(_exiting_max_slippage,ORDER_SET_SHORT,magic);
   else if(exit_signal==DIRECTION_BIAS_SELL)  exit_all_trades_set(_exiting_max_slippage,ORDER_SET_LONG,magic);*/
   
   if(breakeven_threshold_percent>0) breakeven_check_all_orders(breakeven_threshold_percent,breakeven_plus_percent,magic);
   if(trail_threshold_percent>0) trailingstop_check_all_orders(trail_threshold_percent,trail_step_percent,magic,same_stoploss_distance);
   //   virtualstop_check(virtual_sl,virtual_tp); 
   if(is_new_M5_bar) // only check if it is in the time range once the EA is loaded and, then, afterward at the beginning of every M5 bar
     {
      //Print("Got past is_new_M5_bar");
      if(active_order_expire>0) exit_all_trades_set(_exiting_max_slippage,ORDER_SET_MARKET,magic,(int)(active_order_expire*3600),current_time); // This runs every 5 minutes (whether the time is in_time_range or not). It only exit trades that have been on for too long and haven't hit stoploss or takeprofit.
      in_time_range=in_time_range(current_time,start_time_hour,start_time_minute,end_time_hour,end_time_minute,fri_end_time_hour,fri_end_time_minute,gmt_hour_offset);
      
      if(current_chart_matches)
        {
          double bid_price=MarketInfo(current_chart,MODE_BID);
          if(ObjectFind(current_chart+"_day_of_week")<0)
            {
              ObjectCreate(current_chart+"_day_of_week",OBJ_TEXT,0,TimeCurrent(),bid_price);
              ObjectSetText(current_chart+"_day_of_week","0",15,NULL,clrWhite);
            }
          ObjectSetText(current_chart+"_day_of_week",IntegerToString(DayOfWeek(),1),0);
          ObjectMove(current_chart+"_day_of_week",0,TimeCurrent(),bid_price+ADR_pts/2);
        }
        /*Print("in time range ",in_time_range);
        Print("ready ",ready);
        Print("avg spread yesterday ",average_spread_yesterday);*/
      
      if(in_time_range==true && ready==false && average_spread_yesterday!=-1) 
        {
         get_changed_ADR_pts(H1s_to_roll,below_ADR_outlier_percent,above_ADR_outlier_percent,change_ADR_percent,instrument);
         average_spread_yesterday=calculate_avg_spread_yesterday(instrument); // 23:05
         
         /*static bool flag=true;
         if(flag)
          {
            Print("Relativity_EA_1: average_spread_yesterday: ",DoubleToString(average_spread_yesterday));
            flag=false;
          }*/
         
         Print("spread pts provided=",average_spread_yesterday);
         bool is_acceptable_spread=acceptable_spread(instrument,max_spread_percent,true,average_spread_yesterday,false); // ADR_pts must be >0 before calling this function
         
         if(is_acceptable_spread==false) 
           {
            /*Steps that were used to calculate percent_allows_trading:
            
            double max_spread=((ADR_pts)*max_spread_percent);
            double spread_diff=average_spread_yesterday-max_spread;
            double spread_diff_percent=spread_diff/(ADR_pips);
            double percent_allows_trading=spread_diff_percent+max_spread_percent;*/
            double percent_allows_trading=NormalizeDouble(((average_spread_yesterday-(ADR_pts*max_spread_percent))/ADR_pts)+max_spread_percent,3);
            
            Alert(instrument," can't be traded today because the average spread yesterday does not meet your max_spread_percent (",
                  DoubleToStr(max_spread_percent,3),") of ADR criteria. The average spread yesterday was ",
                  DoubleToStr(average_spread_yesterday,3),
                  ". A max_spread_percent value above ",
                  DoubleToStr(percent_allows_trading,3),
                  " would have allowed the EA make trades in this currency pair today.");
            average_spread_yesterday=-1; // keep this at -1 because an if statement depends on it
           }
          /*static bool flag4=false;
          if(flag4==false)
            {
              Print("ADR points are ",DoubleToStr(ADR_pts)," at ",TimeToString(current_time));
              Print("is_acceptable_spread is ",is_acceptable_spread," at ", TimeToString(current_time));
          
              flag4=true;       
            }*/   
          if(ADR_pts>0 && magic>0 && is_acceptable_spread==true)
           {
            // reset all trend analysis and uptrend/downtrend alternating to start fresh for the day
            uptrend_trade_happened_last=false;
            downtrend_trade_happened_last=false;
            uptrend=false;
            downtrend=false;
            ObjectSet(current_chart+"_HOP",OBJPROP_WIDTH,1); 
            ObjectSet(current_chart+"_LOP",OBJPROP_WIDTH,1);   
            ready=true; // the ADR and average spread yesterday that has just been calculated won't generate again until after the cycle of not being in the time range completes
            
            /*static bool flag3=false;
            if(flag3==false)
              {
                Print("ready set to true at ",TimeToString(current_time));
                flag3=true;       
              }*/
           }
         else ready=false; // never assign average_spread_yesterday to anything in this scope
        }
     }
   if(ready && in_time_range)
     {
      int enter_signal=DIRECTION_BIAS_NEUTRAL; // 0

      if(is_new_M5_bar) moves_start_bar=get_moves_start_bar(instrument,H1s_to_roll,gmt_hour_offset,max_weekend_gap_percent,include_last_week); // this is here so the vertical line can get moved every 5 minutes
      enter_signal=signal_retracement_pullback_after_ADR_triggered(instrument);
      if(enter_signal>0 || enter_signal==DIRECTION_BIAS_IGNORE) 
        enter_signal=signal_bias_compare(enter_signal,signal_MA(instrument),false);
        
      if(enter_signal>0) 
        {
         // the code for every filter after this line needs to know whether the signal was to buy or sell and, therefore, couldn't be in the previous filters
         int days_seconds=(int)(current_time-(iTime(instrument,PERIOD_D1,0))+(gmt_hour_offset*3600)); // i am assuming it is okay to typecast a datetime (iTime) into an int since datetime is count of the number of seconds since 1970
         //int efficient_end_index=MathMin((MathMax(max_trades_within_x_hours*x_hours,max_directional_trades_each_day*24)*max_directional_trades_at_once*max_num_EAs_at_once-1),OrdersHistoryTotal()-1); // calculating the maximum orders that could have been placed so at least the program doesn't have to iterate through all orders in history (which can slow down the EA)
         
         if(reverse_trade_direction==true)
           {
             if(enter_signal==DIRECTION_BIAS_BUY) enter_signal=DIRECTION_BIAS_SELL;
             else if(enter_signal==DIRECTION_BIAS_SELL) enter_signal=DIRECTION_BIAS_BUY;
           }
         if(enter_signal==DIRECTION_BIAS_BUY)
           {
            Print("try_to_enter_order: OP_BUY");
            try_to_enter_order(OP_BUY,magic,entering_max_slippage_pips,instrument);
            
            
            /*ENUM_ORDER_SET order_set=ORDER_SET_LONG;
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
                bool overbought_1=false;
                bool overbought_2=false;
                if(filter_over_extended_trends)
                  {
                    RefreshRates();
                    overbought_1=over_extended_trend(instrument,3,BUYING_MODE,HIGH_MINUS_LOW,.75,3,false);
                    overbought_2=over_extended_trend(instrument,3,BUYING_MODE,OPEN_MINUS_CLOSE_ABSOLUTE,.75,3,false);           
                  }
                if(!overbought_1 || !overbought_2) 
                  {
                    Print("try_to_enter_order: OP_BUY");
                    try_to_enter_order(OP_BUY,magic,entering_max_slippage_pips,instrument);
                  }
              }*/
           }
         else if(enter_signal==DIRECTION_BIAS_SELL)
           {   
            Print("try_to_enter_order: OP_SELL");
            try_to_enter_order(OP_SELL,magic,entering_max_slippage_pips,instrument);
            
            
            
            /*ENUM_ORDER_SET order_set=ORDER_SET_SHORT;
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
                bool oversold_1=false;
                bool oversold_2=false;
                if(filter_over_extended_trends)
                  {
                    RefreshRates();
                    oversold_1=over_extended_trend(instrument,3,SELLING_MODE,HIGH_MINUS_LOW,.75,3,false);
                    oversold_2=over_extended_trend(instrument,3,SELLING_MODE,OPEN_MINUS_CLOSE_ABSOLUTE,.75,3,false);
                  }
                if(!oversold_1 || !oversold_2) 
                  {
                    Print("try_to_enter_order: OP_SELL");
                    try_to_enter_order(OP_SELL,magic,entering_max_slippage_pips,instrument);
                  }
              }*/
           }
        }
     }
    else if(in_time_range==false)
     {
       ready=false; // this makes sure to set it to false so when the time is within the time range again, the ADR can get generated
       average_spread_yesterday=0; // do not change this from 0
       //ADR_pts=0; // ADR_pts can't be set to 0 here because the trailing and breakeven functions need ADR_pts
       
      /*static bool flag1=false;
      if(flag1==false)
        {
          Print("not in time range: ",TimeToString(current_time));
          flag1=true;       
        }*/
       if(exit_trades_EOD && is_new_M5_bar)
        {
          bool daily_time_to_exit=time_to_exit(current_time,exit_time_hour,exit_time_minute,gmt_hour_offset);
          if(daily_time_to_exit) 
            {
              exit_all_trades_set(_exiting_max_slippage,ORDER_SET_ALL,magic); // this is the special case where you can exit open and pending trades based on a specified time (this should have been set to be outside of the trading time range)
              
              /*static bool flag=false;
              if(flag==false)
                {
                  Print("time_to_exit: ",TimeToString(current_time));
                  flag=true;
                }*/
            }
          //Alert(time_to_exit);
        }
       if(DayOfWeek()==5 && exit_before_friday_close)
         {
            bool fri_time_to_exit=time_to_exit(current_time,fri_exit_time_hour,fri_exit_time_min,gmt_hour_offset);
            if(fri_time_to_exit) 
              {
                exit_all_trades_set(_exiting_max_slippage,ORDER_SET_ALL,magic); // this is the special case where you can exit open and pending trades based on a specified time (this should have been set to be outside of the trading time range)
              
                /*static bool flag5=false;
                if(flag5==false)
                  {
                    Print("fri_time_to_exit is true");
                    flag5=true;
                  }*/
              }
         }
       if(is_new_M5_bar && ObjectFind(current_chart+"_HOP")>=0)
         {
           // TODO: try the ObjectsDeleteAll function
           ObjectDelete(current_chart+"_HOP");
           ObjectDelete(current_chart+"_LOP");
           ObjectDelete(current_chart+"_Move_Start");
           ObjectDelete(current_chart+"_retrace_HOP_up");
           ObjectDelete(current_chart+"_retrace_HOP_down");
           ObjectDelete(current_chart+"_retrace_LOP_up");
           ObjectDelete(current_chart+"_retrace_LOP_down");
           
           //ObjectDelete(current_chart+"_Move_Start");
         }    
       /*if(ObjectFind(current_chart+"_end_time")<0) 
          {
            ObjectCreate(current_chart+"_end_time",OBJ_VLINE,0,current_time,Bid);
            ObjectSet(current_chart+"_end_time",OBJPROP_COLOR,clrWhite);
          }
       else
          {
            ObjectMove(current_chart+"_end_time",0,current_time,Bid);
          }*/       
     }
    return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void get_point_multiplier(string instrument)
  {  
    int digits=(int)MarketInfo(instrument,MODE_DIGITS);
    if(auto_adjust_broker_digits==true && (digits==3 || digits==5))
      {
        Print("Your broker's rates have ",IntegerToString(digits)," digits after the decimal point. Therefore, to keep the math in the EA as it was intended, some pip values will be automatically multiplied by 10. You do not have to do anything.");
        point_multiplier=10;
      }
    else
      point_multiplier=1;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------
/*int signal_MA_crossover(double a1,double a2,double b1,double b2)
  {
   ENUM_DIRECTION_BIAS signal=TRADE_SIGNAL_NEUTRAL;
   if(a1<b1 && a2>=b2)
     {
      signal=TRADE_SIGNAL_BUY;
     }
   else if(a1>b1 && a2<=b2)
     {
      signal=TRADE_SIGNAL_SELL;
     }
   return signal;
  }*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int signal_MA(string instrument)
  {
   if(moving_avg_period<=0) return DIRECTION_BIAS_IGNORE;
   else
     {
       int ma_shift=0;
       ENUM_MA_METHOD ma_method=MODE_SMA;
       ENUM_APPLIED_PRICE ma_applied=PRICE_MEDIAN;
       int ma_index=1;
       
       double ma=iMA(instrument,PERIOD_M5,moving_avg_period,ma_shift,ma_method,ma_applied,ma_index);
       double ma1=iMA(instrument,PERIOD_M5,moving_avg_period,ma_shift,ma_method,ma_applied,ma_index+1);
       double close=iClose(instrument,PERIOD_M5,ma_index);
       double close1=iClose(instrument,PERIOD_M5,ma_index+1);
       if(ma<close && ma1>close1)
         {
          return DIRECTION_BIAS_BUY;
         }
       else if(ma>close && ma1<close1)
         {
          return DIRECTION_BIAS_SELL;
         }
       return DIRECTION_BIAS_NEUTRAL;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool over_extended_trend(string instrument,int days_to_check,ENUM_DIRECTIONAL_MODE mode,ENUM_RANGE range,double days_range_percent_threshold,int num_to_be_true,bool dont_analyze_today=false)
    {
    static int new_days_to_check=0;
    int digits=(int)MarketInfo(instrument,MODE_DIGITS);
    double ADR_points_threshold=NormalizeDouble(ADR_pts*days_range_percent_threshold,digits);
    double previous_days_close=-1;
    double bid_price=MarketInfo(instrument,MODE_BID); // RefreshRates() always has to be called before getting the price. In this case, it was run before calling this function.
    bool answer=false;
    int uptrend_count=0, downtrend_count=0;
    int sat_sun_count=0;
    int lower_index=(int)dont_analyze_today;
    
    if(is_new_custom_D1_bar || new_days_to_check==0) // get the new value of the static sunday_count the first time it is run or if it is a new day
      {
        new_days_to_check=0; // do not delete this line
        for(int i=days_to_check-1+lower_index;i>=lower_index;i--)
          {
            int day=TimeDayOfWeek(iTime(instrument,PERIOD_D1,i));
          
            if(day==0 || day==6) // count Sundays
              {
                sat_sun_count++;
              }
          }    
      }
    if(sat_sun_count>0) new_days_to_check=sat_sun_count+days_to_check;
    if(mode==BUYING_MODE)
      {
        for(int i=new_days_to_check-1+lower_index;i>=lower_index;i++) // days_to_check should be past days to check + today
          {
            double open_price=iOpen(instrument,PERIOD_D1,i), close_price=iClose(instrument,PERIOD_D1,i);
            
            if(new_days_to_check!=days_to_check) // if there are Sundays in this range
              {
                int day=TimeDayOfWeek(iTime(instrument,PERIOD_D1,i));
                if(day==0) break; // if the bar is Sunday, skip this day            
              }
            double days_range=0;
            if(range==HIGH_MINUS_LOW)
              {
                if(i!=0) days_range=iHigh(instrument,PERIOD_D1,i)-iLow(instrument,PERIOD_D1,i);
                else days_range=bid_price-iLow(instrument,PERIOD_D1,i);
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
                previous_days_close=iClose(instrument,PERIOD_D1,i+1); // this is different than the close_price because it is i+1
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
            double open_price=iOpen(instrument,PERIOD_D1,i), close_price=iClose(instrument,PERIOD_D1,i);
            
            if(new_days_to_check!=days_to_check)
              {
                int day=TimeDayOfWeek(iTime(instrument,PERIOD_D1,i));
                if(day==0) break; // if the bar is Sunday, skip this day
              }
            double days_range=0;
            if(range==HIGH_MINUS_LOW) 
              {
                if(i!=0) days_range=iHigh(instrument,PERIOD_D1,i)-iLow(instrument,PERIOD_D1,i);
                else days_range=iHigh(instrument,PERIOD_D1,i)-bid_price;
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
                previous_days_close=iClose(instrument,PERIOD_D1,i+1); // this is different than close_price because it is i+1
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
int signal_pullback_after_ADR_triggered(string instrument)
  {
    int signal=DIRECTION_BIAS_NEUTRAL;
 
    if(uptrend_trade_happened_last==false /*&& uptrend==false*/) // if there is no uptrend, monitor the market for an uptrend. But stopped monitoring it if a uptrend has been identified.
      {
        RefreshRates();
        if(uptrend_ADR_threshold_met_price(instrument,false)>0)
          {
            return signal=DIRECTION_BIAS_BUY; // FYI, when using the signal_retracement_pullback_after_ADR_triggered for signals, this return value has absolutely no affect.
          }
      }
   // for a buying signal, take the level that adr was triggered and subtract the pullback_pips to get the pullback_entry_price
   // if the pullback_entry_price is met or exceeded, signal = TRADE_SIGNAL_BUY
    if(downtrend_trade_happened_last==false /*&& downtrend==false*/) // if there is no downtrend, monitor the market for a downtrend. But stopped monitoring it if a downtrend has been identified.
      {
        RefreshRates();
        if(downtrend_ADR_threshold_met_price(instrument,false)>0) 
          {
            return signal=DIRECTION_BIAS_SELL; // FYI, when using the signal_retracement_pullback_after_ADR_triggered for signals, this return value has absolutely no affect.
          }
      }
    return signal;
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int signal_retracement_pullback_after_ADR_triggered(string instrument)
  {
    signal_pullback_after_ADR_triggered(instrument); // this must be here because it is used to calculate and assign some values required within the below functions
    int signal=DIRECTION_BIAS_NEUTRAL;
    if(uptrend_retracement_met_price(instrument,false)>0) signal=DIRECTION_BIAS_BUY;
    //if(signal==DIRECTION_BIAS_BUY) Print("buy signal");
    if(downtrend_retracement_met_price(instrument,false)>0) signal=DIRECTION_BIAS_SELL;
    
    //Print("signal_retracement_pullback_after_ADR_triggered returned: ",signal);
    return signal;
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Checks for the entry of orders
int signal_entry(string instrument,ENUM_SIGNAL_SET signal_set) // gets called for every tick
  {
   int signal=DIRECTION_BIAS_NEUTRAL;
   
/* Add 1 or more entry signals below. 
   With more than 1 signal, you would follow this code using the signal_compare function. 
   "signal=signal_compare(signal,signal_pullback_after_ADR_triggered());"
   As each signal is compared with the previous signal, the signal variable will change and then the final signal wil get returned.
*/
   if(signal_set==SIGNAL_SET_1)
     {
      signal=signal_bias_compare(signal,signal_MA(instrument),false);
      return signal;
     }
   if(signal_set==SIGNAL_SET_2)
     {
      return signal;
     }
   else return DIRECTION_BIAS_NEUTRAL;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Checks for the exit of orders
int signal_exit(string instrument,ENUM_SIGNAL_SET signal_set)
  {
   int signal=DIRECTION_BIAS_NEUTRAL;
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
int signal_bias_compare(int current_bias,int added_bias,bool exit_when_buy_and_sell=false) 
  {
  // signals are evaluated two at a time and the result will be used to compared with other signals until all signals are compared
   if(current_bias==DIRECTION_BIAS_VOID || added_bias==DIRECTION_BIAS_VOID) return DIRECTION_BIAS_VOID;
   else if(current_bias==DIRECTION_BIAS_NEUTRAL || added_bias==DIRECTION_BIAS_NEUTRAL) return DIRECTION_BIAS_NEUTRAL;
   else if(current_bias==DIRECTION_BIAS_IGNORE) return added_bias;
   else if(added_bias==DIRECTION_BIAS_IGNORE) return current_bias;
   // at this point, the only two options left are if they are both buy, both sell, or buy and sell
   else if(added_bias!=current_bias) // if one bias is a bullish and the other is bearish
    {
     if(exit_when_buy_and_sell) return DIRECTION_BIAS_VOID;
     else return DIRECTION_BIAS_NEUTRAL;
    }
   return added_bias; // at this point, the added_bias and current_bias must be the same signal so it can get returned
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Neutralizes situations where there is a conflict between the entry and exit signal.
// TODO: This function is not yet being called. Since the entry and exit signals are passed by reference, these paremeters would need to be prepared in advance and stored in variables prior to calling the function.
void signal_manage(ENUM_DIRECTION_BIAS &entry,ENUM_DIRECTION_BIAS &exit)
  {
   if(exit==DIRECTION_BIAS_VOID)                                  entry=DIRECTION_BIAS_NEUTRAL;
   if(exit==DIRECTION_BIAS_BUY && entry==DIRECTION_BIAS_SELL)     entry=DIRECTION_BIAS_NEUTRAL;
   if(exit==DIRECTION_BIAS_SELL && entry==DIRECTION_BIAS_BUY)     entry=DIRECTION_BIAS_NEUTRAL;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int generate_magic_num(string instrument, ENUM_SIGNAL_SET)
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


   int i, combined_letter_int=0, letter_int=0;
   for(i=0; i<StringLen(instrument); i++)
     {
      letter_int=StringGetChar(instrument,i);
      //Print(combined_letter_int,"+",letter_int);
      combined_letter_int=(combined_letter_int<<5)+combined_letter_int+letter_int; // << Bitwise Left shift operator shifts all bits towards left by certain number of specified bits.
      //Print(combined_letter_int);
     }
   return(combined_letter_int);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool in_time_range(datetime time,int start_hour,int start_min,int end_hour,int end_min,int fri_end_time_hr, int fri_end_time_min, int gmt_offset=0)
  {
   string current_chart=Symbol();
   double bid_price=MarketInfo(current_chart,MODE_BID);
   int day=TimeDayOfWeek(time);
   
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
      fri_end_time_hr+=gmt_offset;
     }
// Since a non-zero gmt_offset will make the start and end hour go beyond acceptable paremeters (below 0 or above 23), change the start_hour and end_hour to military time.
   if(start_hour>23) start_hour=(start_hour-23)-1;
   else if(start_hour<0) start_hour=(23+start_hour)+1;
   if(end_hour>23) end_hour=(end_hour-23)-1;
   else if(end_hour<0) end_hour=(23+end_hour)+1;
   
   /*Print("start_hour: ",start_hour);
   Print("start_min: ",start_min);
   Print("end_hour: ",end_hour);
   Print("end_min: ",end_min);*/
    
   int current_time=(TimeHour(time)*3600)+(TimeMinute(time)*60);
   int start_time=(start_hour*3600)+(start_min*60);
   int end_time=(end_hour*3600)+(end_min*60);
   
   //Print("current_time ",TimeToStr(current_time));
   //Print("start_time ",TimeToStr(start_time));
   //Print("end_time ",TimeToStr(end_time));
   
   if(ObjectFind(current_chart+"_start_time_today")<0) 
      {
        ObjectCreate(current_chart+"_start_time_today",OBJ_VLINE,0,iTime(current_chart,PERIOD_D1,0)+start_time,bid_price);
        ObjectSet(current_chart+"_start_time_today",OBJPROP_COLOR,clrGreen);
        ObjectCreate(current_chart+"_start_time_yesterday",OBJ_VLINE,0,iTime(current_chart,PERIOD_D1,1)+start_time,bid_price);
        ObjectSet(current_chart+"_start_time_yesterday",OBJPROP_COLOR,clrGreen);

        ObjectCreate(current_chart+"_end_time_today",OBJ_VLINE,0,iTime(current_chart,PERIOD_D1,0)+end_time,bid_price);
        ObjectSet(current_chart+"_end_time_today",OBJPROP_COLOR,clrRed);
        ObjectCreate(current_chart+"_end_time_yesterday",OBJ_VLINE,0,iTime(current_chart,PERIOD_D1,1)+end_time,bid_price);
        ObjectSet(current_chart+"_end_time_yesterday",OBJPROP_COLOR,clrRed);
      }
   else
      {
        ObjectMove(current_chart+"_start_time_today",0,iTime(current_chart,PERIOD_D1,0)+start_time,bid_price);
        ObjectMove(current_chart+"_start_time_yesterday",0,iTime(current_chart,PERIOD_D1,1)+start_time,bid_price); 
        ObjectMove(current_chart+"_end_time_today",0,iTime(current_chart,PERIOD_D1,0)+end_time,bid_price);
        ObjectMove(current_chart+"_end_time_yesterday",0,iTime(current_chart,PERIOD_D1,1)+end_time,bid_price);       
      }

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
   if(gmt_offset!=0) 
     {
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
     string current_chart=Symbol();
     double bid_price=MarketInfo(current_chart,MODE_BID);
     
     if(ObjectFind(current_chart+"_time_to_exit")<0)
        {
          ObjectCreate(current_chart+"_time_to_exit",OBJ_VLINE,0,TimeCurrent(),bid_price);
          ObjectSet(current_chart+"_time_to_exit",OBJPROP_COLOR,clrRed);
          ObjectSet(current_chart+"_time_to_exit",OBJPROP_STYLE,STYLE_DASH);            
        }
     else
        {
          ObjectMove(current_chart+"_time_to_exit",0,TimeCurrent(),bid_price); // TODO: this statement will run for every single instrument
        }
     return true; // this will only give the signal to exit for every tick for 1 minute per day
    }
   else return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/*bool is_new_bar(ENUM_TIME_FRAMES timeframe)
  {
    switch(timeframe)
      {
        case M5:
          {
           static datetime M5_bar_time=0;
           static double M5_open_price=0;
           datetime M5_current_bar_open_time=iTime(Symbol(),PERIOD_M5,0);
           double M5_current_bar_open_price=iOpen(Symbol(),PERIOD_M5,0);
           int digits=(int)MarketInfo(Symbol(),MODE_DIGITS);
           
           if(M5_bar_time==0 && M5_open_price==0) // If it is the first time the function is called or it is the start of a new bar. This could be after the open time (aka in the middle) of a bar.
             {
              M5_bar_time=M5_current_bar_open_time;
              M5_open_price=M5_current_bar_open_price;
              if(wait_for_next_bar) return false; // after loading the EA for the first time, if the user wants to wait for the next bar for the bar to be considered new
              else return true;
             }
           else if(M5_current_bar_open_time>M5_bar_time && compare_doubles(M5_open_price,M5_current_bar_open_price,digits)!=0) // if the opening time and price of this bar is different than the opening time and price of the previous one
             {
              M5_bar_time=M5_current_bar_open_time; // assuring the true value only gets returned for 1 tick and not the very next ones
              M5_open_price=M5_current_bar_open_price; // assuring the true value only gets returned for 1 tick and not the very next ones
              return true;
             }
           else return false;
          }
        case D1:
        case W1:
      }
  }*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_new_M5_bar(bool wait_for_next_bar=false)
  {
   static datetime M5_bar_time=0;
   static double M5_open_price=0;
   datetime M5_current_bar_open_time=iTime(NULL,PERIOD_M5,0);
   double M5_current_bar_open_price=iOpen(NULL,PERIOD_M5,0);
   int digits=(int)MarketInfo(NULL,MODE_DIGITS);
   
   if(M5_bar_time==0 && M5_open_price==0) // If it is the first time the function is called or it is the start of a new bar. This could be after the open time (aka in the middle) of a bar.
     {
      M5_bar_time=M5_current_bar_open_time;
      M5_open_price=M5_current_bar_open_price;
      if(wait_for_next_bar) return false; // after loading the EA for the first time, if the user wants to wait for the next bar for the bar to be considered new
      else return true;
     }
   else if(M5_current_bar_open_time>M5_bar_time && compare_doubles(M5_open_price,M5_current_bar_open_price,digits)!=0) // if the opening time and price of this bar is different than the opening time and price of the previous one
     {
      M5_bar_time=M5_current_bar_open_time; // assuring the true value only gets returned for 1 tick and not the very next ones
      M5_open_price=M5_current_bar_open_price; // assuring the true value only gets returned for 1 tick and not the very next ones
      return true;
     }
   else return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_new_H1_bar()
  {
     static datetime H1_bar_time=0;
     static double H1_open_price=0;
     datetime H1_current_bar_open_time=iTime(NULL,PERIOD_H1,0);
     double H1_current_bar_open_price=iOpen(NULL,PERIOD_H1,0);
     int digits=(int)MarketInfo(NULL,MODE_DIGITS);
     
     if(H1_bar_time==0 && H1_open_price==0) // If it is the first time the function is called or it is the start of a new bar. This could be after the open time (aka in the middle) of a bar.
       {
        H1_bar_time=H1_current_bar_open_time;
        H1_open_price=H1_current_bar_open_price;
        return true; // wait for the next bar for this function to return true
       }
     else if(H1_current_bar_open_time>H1_bar_time && compare_doubles(H1_open_price,H1_current_bar_open_price,digits)!=0) // if the opening time and price of this bar is different than the opening time and price of the previous one
       {
        H1_bar_time=H1_current_bar_open_time; // assuring the true value only gets returned for 1 tick and not the very next ones
        H1_open_price=H1_current_bar_open_price; // assuring the true value only gets returned for 1 tick and not the very next ones
        return true;
       }
     else return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_new_custom_D1_bar()
  {  
     static datetime D1_bar_time=0;
     static double D1_open_price=0;
     datetime D1_current_bar_open_time=iTime(NULL,PERIOD_D1,0)+(gmt_hour_offset*3600);
     double D1_current_bar_open_price=iOpen(NULL,PERIOD_M5,iBarShift(NULL,PERIOD_M5,D1_current_bar_open_time,false));
     int digits=(int)MarketInfo(NULL,MODE_DIGITS);
     
     if(D1_bar_time==0 && D1_open_price==0) // If it is the first time the function is called or it is the start of a new bar. This could be after the open time (aka in the middle) of a bar.
       {
        D1_bar_time=D1_current_bar_open_time;
        D1_open_price=D1_current_bar_open_price;
        return true; // wait for the next bar for this function to return true
       }
     else if(D1_current_bar_open_time>D1_bar_time && compare_doubles(D1_open_price,D1_current_bar_open_price,digits)!=0) // if the opening time and price of this bar is different than the opening time and price of the previous one
       {
        D1_bar_time=D1_current_bar_open_time; // assuring the true value only gets returned for 1 tick and not the very next ones
        D1_open_price=D1_current_bar_open_price; // assuring the true value only gets returned for 1 tick and not the very next ones
        return true;
       }
     else return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_new_custom_W1_bar()
  {
     static datetime W1_bar_time=0;
     static double W1_open_price=0;
     datetime W1_current_bar_open_time=0;
     double W1_current_bar_open_price=0;
     int digits=(int)MarketInfo(NULL,MODE_DIGITS);
     
     //datetime week_start_open_time=iTime(NULL,PERIOD_W1,0)+(gmt_offset*3600); // The iTime of the week bar gives you the time that the week is 0:00 on the chart so I shifted the time to start when the markets actually start.
     int day=DayOfWeek();
     if(day>1 && day<7) return true; // If the day is tuesday through saturday, return false. (Intentionally leaving out Monday and Sunday.)
       
     for(int i=0;i<7;i++) // get the week start information only
      {
        bool got_monday=false;
        if(got_monday==true) break;
        else
          {
            datetime days_start_time=iTime(NULL,PERIOD_D1,i);
            int i_day=TimeDayOfWeek(days_start_time);
            if(i_day==1) // if it is monday
              {
                W1_current_bar_open_time=days_start_time+(gmt_hour_offset*3600);
                int weeks_start_bar=iBarShift(NULL,PERIOD_M5,W1_current_bar_open_time,false);
                W1_current_bar_open_price=iOpen(NULL,PERIOD_M5,weeks_start_bar);
                got_monday=true;
              }   
          }
      }  
     if(W1_bar_time==0 && W1_open_price==0) // If it is the first time the function is called or it is the start of a new bar. This could be after the open time (aka in the middle) of a bar.
       {
        W1_bar_time=W1_current_bar_open_time;
        W1_open_price=W1_current_bar_open_price;
        return false; // wait for the next bar for this function to return true
       }
     else if(W1_current_bar_open_time>W1_bar_time && compare_doubles(W1_open_price,W1_current_bar_open_price,digits)!=0) // if the opening time and price of this bar is different than the opening time and price of the previous one
       {
        W1_bar_time=W1_current_bar_open_time; // assuring the true value only gets returned for 1 tick and not the very next ones
        W1_open_price=W1_current_bar_open_price; // assuring the true value only gets returned for 1 tick and not the very next ones
        return true;
       }
     else return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double ADR_calculation(string instrument,double low_outlier,double high_outlier/*,double change_by*/)
  {
     int three_mnth_sat_sun_count=0;
     int three_mnth_num_days=3*22; // There are about 22 business days a month.
     
     for(int i=three_mnth_num_days;i>0;i--) // count the number of Sundays in the past 6 months
        {
        int day=TimeDayOfWeek(iTime(instrument,PERIOD_D1,i));
        
        if(day==0 || day==6) // count Saturdays and Sundays
          {
           three_mnth_sat_sun_count++;
          }
        }
     double avg_sat_sun_per_day=three_mnth_sat_sun_count/three_mnth_num_days;
     int six_mnth_adjusted_num_days=(int)(((avg_sat_sun_per_day*three_mnth_num_days)+three_mnth_num_days)*2); // accurately estimate how many D1 bars you would have to go back to get the desired number of days to look back
     int six_mnth_non_sunday_count=0;
     double six_mnth_non_sunday_ADR_sum=0;
     
     for(int i=six_mnth_adjusted_num_days;i>0;i--) // get the raw ADR (outliers are included but not Sunday's outliers) for the approximate past 6 months
     {
      int day=TimeDayOfWeek(iTime(instrument,PERIOD_D1,i));
     
      if(day!=0 && day!=6) // if the day of week is not Saturday or Sunday
        {
         double HOD=iHigh(instrument,PERIOD_D1,i);
         double LOD=iLow(instrument,PERIOD_D1,i);
         six_mnth_non_sunday_ADR_sum+=HOD-LOD;
         six_mnth_non_sunday_count++;
        }
     }
     
     int digits=(int)MarketInfo(instrument,MODE_DIGITS);
     double six_mnth_ADR_avg=NormalizeDouble(six_mnth_non_sunday_ADR_sum/six_mnth_non_sunday_count,digits); // the first time getting the ADR average
     six_mnth_non_sunday_ADR_sum=0;
     six_mnth_non_sunday_count=0;
     
     for(int i=six_mnth_adjusted_num_days;i>0;i--) // refine the ADR (outliers and Sundays are NOT included) for the approximate past 6 months
       {
        int day=TimeDayOfWeek(iTime(instrument,PERIOD_D1,i));
             
        if(day!=0 && day!=6) // if the day of week is not Sunday
          {
           double HOD=iHigh(instrument,PERIOD_D1,i);
           double LOD=iLow(instrument,PERIOD_D1,i);
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
     int x_mnth_adjusted_num_days=(int)((avg_sat_sun_per_day*x_mnth_num_days)+x_mnth_num_days); // accurately estimate how many D1 bars you would have to go back to get the desired number of days to look back
     
     for(int i=x_mnth_adjusted_num_days;i>0;i--) // find the counts of all days that are significantly below or above ADR
       {
        int day=TimeDayOfWeek(iTime(instrument,PERIOD_D1,i));
             
        if(day!=0 && day!=6) // if the day of week is not Sunday
          {
           double HOD=iHigh(instrument,PERIOD_D1,i);
           double LOD=iLow(instrument,PERIOD_D1,i);
           double days_range=HOD-LOD;
           double ADR_ratio=NormalizeDouble(days_range/six_mnth_ADR_avg,2); // ratio for comparing the current iteration with the 6 month average
           
           if(compare_doubles(ADR_ratio,low_outlier,2)==1 && compare_doubles(ADR_ratio,high_outlier,2)==-1) // filtering out outliers // you may not have to use compare_doubles()
             {
              x_mnth_non_sunday_ADR_sum+=days_range;
              x_mnth_non_sunday_count++;
             }
          }
       }
     double adr_pts=NormalizeDouble((x_mnth_non_sunday_ADR_sum/x_mnth_non_sunday_count),digits);
     Print("ADR_calculation returned: ",DoubleToStr(adr_pts,digits));
     return adr_pts;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double get_raw_ADR_pts(string instrument,double hours_to_roll,double low_outlier,double high_outlier/*,double change_by*/) // get the Average Daily Range
  {
    static double _adr_pts=0;
    int _num_ADR_months=num_ADR_months;
     
    if(low_outlier>high_outlier || _num_ADR_months<=0 || _num_ADR_months==NULL || MathMod(hours_to_roll,.5)!=0) // TODO: hours_to_roll is not used in this function except for this line
      {
        return -1; // if the user inputed the wrong outlier variables or a H1s_to_roll number that is not divisible by .5, it is not possible to calculate ADR
      }  
    if(_adr_pts==0 || is_new_custom_D1_bar) // if it is the first time the function is called
      {
        double calculated_adr_pts=ADR_calculation(instrument,low_outlier,high_outlier/*,change_by*/);
        _adr_pts=calculated_adr_pts; // make the function remember the calculation the next time it is called
        return _adr_pts;
      }
    return _adr_pts; // if it is not the first time the function is called it is the middle of a bar, return the static adr
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void get_changed_ADR_pts(double hours_to_roll,double low_outlier,double high_outlier,double change_by_percent,string instrument) // get the Average Daily Range
  {
     double   raw_ADR_pts=get_raw_ADR_pts(instrument,hours_to_roll,low_outlier,high_outlier);
     int      digits=(int)MarketInfo(instrument,MODE_DIGITS);
     int      point=(int)MarketInfo(instrument,MODE_POINT);
     string   current_chart=Symbol();
     double   bid_price=MarketInfo(current_chart,MODE_BID);
     
     if(instrument==current_chart && ObjectFind(current_chart+"_ADR_pts")<0) 
      {
        ObjectCreate(current_chart+"_ADR_pts",OBJ_TEXT,0,TimeCurrent(),bid_price);
        ObjectSetText(current_chart+"_ADR_pts","0",15,NULL,clrWhite);
      } 
     if(raw_ADR_pts>0 && (change_by_percent==0 || change_by_percent==NULL))
      { 
        Print("A raw ADR of ",DoubleToString(raw_ADR_pts,digits)," for ",instrument," was generated.");
        ADR_pts=NormalizeDouble(raw_ADR_pts,digits);
        if(instrument==current_chart)
          {
            ObjectSetText(current_chart+"_ADR_pts",DoubleToString(raw_ADR_pts*100,3),0);
            ObjectMove(current_chart+"_ADR_pts",0,TimeCurrent(),bid_price+ADR_pts/4);        
          }
        //Print("raw_ADR_pts: ",DoubleToString(raw_ADR_pts));
      }
     else if(raw_ADR_pts>0)
      {
        double changed_ADR_pts=NormalizeDouble(((raw_ADR_pts*change_by_percent)+raw_ADR_pts),digits); // include the ability to increase\decrease the ADR by a certain percentage where the input is a global variable
        Print("A raw ADR of ",DoubleToString(raw_ADR_pts,digits)," for ",instrument," was generated. As requested by the user, it has been changed to ",DoubleToString(changed_ADR_pts,digits));
        ADR_pts=changed_ADR_pts;
        if(instrument==current_chart)
          {
            ObjectSetText(current_chart+"_ADR_pts",DoubleToString(changed_ADR_pts*100,3),0);
            ObjectMove(current_chart+"_ADR_pts",0,TimeCurrent(),bid_price+ADR_pts/4);        
          }
      }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+  
int get_moves_start_bar(string instrument,double _H1s_to_roll,int gmt_offset,double _max_weekend_gap_percent,bool _include_last_week=true)
  {
   static datetime  weeks_open_time=0; // also known as Monday
   static double    weeks_open_price=0;
   static datetime  last_weeks_end_time=0;
   static double    last_weeks_close_price=0;
   static int       weeks_start_bar=-1;
   int              _moves_start_bar=(int)_H1s_to_roll*12/*-1*/; // any double divisible by .5 will always be an integer when multiplied by an even number like 12 so it is okay to convert it into an int
   string           current_chart=Symbol();
   int              digits=(int)MarketInfo(instrument,MODE_DIGITS); 
   int              day=DayOfWeek();
   static bool      alert_flag=false;
   
   if(day==0 || day==6) // if the day is Sunday or Saturday
     {
       // reset all static variables to the default values
       weeks_open_time=0; // aka Monday
       last_weeks_end_time=0;
       weeks_open_price=0;
       last_weeks_close_price=0;
       weeks_start_bar=-1;
       return 0;
     }
   if(weeks_start_bar==-1 || (day==1 && is_new_custom_W1_bar))
     {
       alert_flag=false;
       if(_include_last_week)
         {
           if(day==1 || (day*24)<_H1s_to_roll) // if it is monday or the H1s_to_roll exceeds the max possible hours since the start of the week
             {
               for(int i=0;i<7;i++) // 7 iterations 
                {
                  bool got_monday=false;
                  bool got_friday=false;
                  if(got_monday && got_friday) break;
                  else
                    {
                      datetime days_start_time=iTime(instrument,PERIOD_D1,i);
                      int i_day=TimeDayOfWeek(days_start_time);
                      if(i_day==1) // if it is monday
                        {
                          weeks_open_time=days_start_time+(gmt_offset*3600);
                          weeks_start_bar=iBarShift(instrument,PERIOD_M5,weeks_open_time,false);
                          weeks_open_price=iOpen(instrument,PERIOD_M5,weeks_start_bar);
                          got_monday=true;
                        }
                      if(i_day==5) // if it is friday
                        {
                          last_weeks_end_time=days_start_time+(86400-1)+(gmt_offset*3600);
                          last_weeks_close_price=iClose(instrument,PERIOD_M5,iBarShift(instrument,PERIOD_M5,last_weeks_end_time,false));
                          if(got_monday) got_friday=true;
                          alert_flag=false;
                        }      
                    }
                }
             }
         }
       else if(!_include_last_week) // if the user's setting is to NOT include last week, the EA should do less work because it doesn't need last week's values
         {
           for(int i=0;i<7;i++) // get the week start information only
            {
              bool got_monday=false;
              if(got_monday) break;
              else
                {
                  datetime days_start_time=iTime(instrument,PERIOD_D1,i);
                  int i_day=TimeDayOfWeek(days_start_time);
                  if(i_day==1) // if it is monday
                    {
                      weeks_open_time=days_start_time+(gmt_offset*3600);
                      weeks_start_bar=iBarShift(instrument,PERIOD_M5,weeks_open_time,false);
                      weeks_open_price=iOpen(instrument,PERIOD_M5,weeks_start_bar);
                      got_monday=true;
                      alert_flag=false;
                    }   
                }
            }
         }
     }
   
   if(ObjectFind(current_chart+"_Move_Start")<0) 
     {
      ObjectCreate(current_chart+"_Move_Start",OBJ_VLINE,0,weeks_open_time,weeks_open_price); // it only gets set to these anchors for 1 M5 bar, so it is okay if it is wrong the first bar.
      ObjectSet(current_chart+"_Move_Start",OBJPROP_COLOR,clrWhite);
     }
   if(_moves_start_bar<=weeks_start_bar)
     {
      ObjectSet(current_chart+"_Move_Start",OBJPROP_TIME1,iTime(current_chart,PERIOD_M5,_moves_start_bar));
      ObjectSet(current_chart+"_Move_Start",OBJPROP_PRICE1,iOpen(current_chart,PERIOD_M5,_moves_start_bar));
      
      // Print("_moves_start_bar ",_moves_start_bar);
      // Print("weeks_start_bar ",weeks_start_bar);
      
      return _moves_start_bar;
     }
   else if(_include_last_week)
     {
      double weekend_gap_points=MathAbs(last_weeks_close_price-weeks_open_price);
      double max_weekend_gap_points=NormalizeDouble(ADR_pts*_max_weekend_gap_percent,digits);

      if(weekend_gap_points>max_weekend_gap_points) // TODO: use compare_doubles()?
        {
          ObjectSet(current_chart+"_Move_Start",OBJPROP_TIME1,iTime(current_chart,PERIOD_M5,weeks_start_bar));
          ObjectSet(current_chart+"_Move_Start",OBJPROP_PRICE1,iOpen(current_chart,PERIOD_M5,weeks_start_bar));
          
          if(alert_flag==false)
            {
              Print("This weekends weekend_gap_points (",DoubleToString(weekend_gap_points),") is > the user's max_weekend_gap_points (",DoubleToString(max_weekend_gap_points),").");
              alert_flag=true;
            }
          
          return weeks_start_bar; 
        }
      else 
        {
          ObjectSet(current_chart+"_Move_Start",OBJPROP_TIME1,iTime(current_chart,PERIOD_M5,_moves_start_bar));
          ObjectSet(current_chart+"_Move_Start",OBJPROP_PRICE1,iOpen(current_chart,PERIOD_M5,_moves_start_bar));
          return _moves_start_bar;
        }
     }
   else
     {
      ObjectSet(current_chart+"_Move_Start",OBJPROP_TIME1,iTime(current_chart,PERIOD_M5,weeks_start_bar));
      ObjectSet(current_chart+"_Move_Start",OBJPROP_PRICE1,iOpen(current_chart,PERIOD_M5,weeks_start_bar));
      return weeks_start_bar;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double periods_pivot_price(ENUM_DIRECTIONAL_MODE mode,string instrument)
  {
    //int moves_start_bar=get_moves_start_bar(instrument,H1s_to_roll,gmt_hour_offset,max_weekend_gap_percent,include_last_week); // not needed anymore since it became a global variable
    
    //Print("move start bar: ",move_start_bar);
    //Print("move start bar's time: ",TimeToString(iTime(instrument,PERIOD_M5,move_start_bar))," and price is: ",iOpen(instrument,PERIOD_M5,move_start_bar));
    
    if(mode==BUYING_MODE)
      { 
        double pivot_price=iLow(instrument,PERIOD_M5,iLowest(instrument,PERIOD_M5,MODE_LOW,moves_start_bar,0)); // get the price of the bar that has the lowest price for the determined period
        //Print("The buying mode pivot_price is: ",DoubleToString(pivot_price));
        //Print("periods_pivot_price(): Bid: ",DoubleToString(Bid));     
        //Print("periods_pivot_price(): Bid-periods_pivot_price: ",DoubleToString(Bid-pivot_price));
        //Print("periods_pivot_price(): ADR_pts: ",DoubleToString(ADR_pts));
        return pivot_price;
      }
    else if(mode==SELLING_MODE)
      {
        double pivot_price=iHigh(instrument,PERIOD_M5,iHighest(instrument,PERIOD_M5,MODE_HIGH,moves_start_bar,0)); // get the price of the bar that has the highest price for the determined period
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
double uptrend_retracement_met_price(string instrument,bool get_current_bid_instead=false)
  {
    string current_chart=Symbol();
    bool current_chart_matches=(current_chart==instrument);
    
    if(uptrend==true && uptrend_trade_happened_last==false && LOP_price>0) // TODO: uptrend_trade_happened_last may be redundant because it is checked before this function even gets called
      {
       RefreshRates();
       static string last_instrument;
       static double retracement_pts=0;
       double range_pts;
       int digits=(int)MarketInfo(instrument,MODE_DIGITS);
       double current_bid=MarketInfo(instrument,MODE_BID); // TODO: always make sure RefreshRates() was called before. In this case, it was called before running this function.
       
       if(last_instrument!=instrument || HOP_price<=0 /*|| LOP_price<=0*/) // if HOP is 0 or -1
        {
         range_pts=range_pts_calculation(OP_BUY,instrument);
         last_instrument=instrument;
         if(compare_doubles(range_pts,ADR_pts,digits)==-1 || HOP_price==-1 /*|| LOP_price==-1*/)
           {
             uptrend=false;
             ObjectSet(current_chart+"_HOP",OBJPROP_WIDTH,1);  
             return -1; // this part is necessary in case periods_pivot_price ever returns 0
           }
         else retracement_pts=NormalizeDouble(range_pts*retracement_percent,digits);
        }
       if(current_bid>HOP_price) // if the high of the range was surpassed // TODO: use compare_doubles()?
         {
           // since the top of the range was surpassed, you have to reset the HOP. You might as well take this opportunity to take the period into account.
           range_pts=range_pts_calculation(OP_BUY,instrument);
           retracement_pts=NormalizeDouble(range_pts*retracement_percent,digits);          
           if(current_chart_matches)
             {
              if(ObjectFind(current_chart+"_retrace_HOP_up")<0)
                {
                  ObjectCreate(current_chart+"_retrace_HOP_up",OBJ_HLINE,0,TimeCurrent(),HOP_price);
                  ObjectSet(current_chart+"_retrace_HOP_up",OBJPROP_COLOR,clrYellow);
                  ObjectSet(current_chart+"_retrace_HOP_up",OBJPROP_STYLE,STYLE_DASH);
                }
              if(ObjectFind(current_chart+"_retrace_LOP_up")<0)
                {
                  ObjectCreate(current_chart+"_retrace_LOP_up",OBJ_HLINE,0,TimeCurrent(),HOP_price-retracement_pts);
                  ObjectSet(current_chart+"_retrace_LOP_up",OBJPROP_COLOR,clrYellow);
                  ObjectSet(current_chart+"_retrace_LOP_up",OBJPROP_STYLE,STYLE_DASH);
                }
              ObjectSet(current_chart+"_retrace_HOP_up",OBJPROP_PRICE1,HOP_price);
              ObjectSet(current_chart+"_retrace_LOP_up",OBJPROP_PRICE1,HOP_price-retracement_pts);       
             }
           return -1;
         } 
       else if(HOP_price-current_bid>=retracement_pts) // if the pip move meets or exceed the ADR_Pips in points, return the current bid. Note: this will return true over and over again // TODO: use compare_doubles()?
         {
           // since the bottom of the range was surpassed and a pending order would be created, this is a good opportunity to update the range in the period since you can't just leave it as the static value constantly
           range_pts=range_pts_calculation(OP_BUY,instrument);
           retracement_pts=NormalizeDouble(range_pts*retracement_percent,digits);

           if(HOP_price-current_bid>=retracement_pts) // TODO: use compare_doubles()?
             {
               if(current_chart_matches)
                 {
                  if(ObjectFind(current_chart+"_retrace_HOP_up")<0)
                    {
                      ObjectCreate(current_chart+"_retrace_HOP_up",OBJ_HLINE,0,TimeCurrent(),HOP_price);
                      ObjectSet(current_chart+"_retrace_HOP_up",OBJPROP_COLOR,clrYellow);
                      ObjectSet(current_chart+"_retrace_HOP_up",OBJPROP_STYLE,STYLE_DASH);
                    }
                  if(ObjectFind(current_chart+"_retrace_LOP_up")<0)
                    {
                      ObjectCreate(current_chart+"_retrace_LOP_up",OBJ_HLINE,0,TimeCurrent(),HOP_price-retracement_pts);
                      ObjectSet(current_chart+"_retrace_LOP_up",OBJPROP_COLOR,clrYellow);
                      ObjectSet(current_chart+"_retrace_LOP_up",OBJPROP_STYLE,STYLE_DASH);
                    }
                  ObjectSet(current_chart+"_retrace_HOP_up",OBJPROP_PRICE1,HOP_price);
                  ObjectSet(current_chart+"_retrace_LOP_up",OBJPROP_PRICE1,HOP_price-retracement_pts);       
                 }
               //Print("uptrend trade should trigger");
               if(get_current_bid_instead) 
                 {
                   return current_bid; // check if it is actually true by taking the new calculation of Low Of Period into account
                 }
               else 
                 {
                   double met_price=HOP_price-retracement_pts;
                   return met_price;
                 }
             }
           else return -1;
         }         
       else return -1;
      }
    else 
      {
        if(uptrend==false && current_chart_matches)
          {
            ObjectDelete(current_chart+"_retrace_HOP_up");
            ObjectDelete(current_chart+"_retrace_LOP_up");     
          }
        return -1;
      }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double downtrend_retracement_met_price(string instrument,bool get_current_bid_instead=false)
  {
    string current_chart=Symbol();
    bool current_chart_matches=(current_chart==instrument);
    
    if(downtrend==true && downtrend_trade_happened_last==false && HOP_price>0) // TODO: uptrend_trade_happened_last may be redundant because it is checked before this function even gets called
      {
       RefreshRates();
       static string last_instrument;
       static double retracement_pts=0;
       double range_pts;
       int digits=(int)MarketInfo(instrument,MODE_DIGITS);
       double current_bid=MarketInfo(instrument,MODE_BID); // TODO: always make sure RefreshRates() was called before. In this case, it was called before running this function.
       
       if(last_instrument!=instrument || LOP_price<=0 /*|| HOP_price<=0*/) // if LOP is 0 or -1
        {
         range_pts=range_pts_calculation(OP_SELL,instrument);
         last_instrument=instrument;
         if(compare_doubles(range_pts,ADR_pts,digits)==-1 || LOP_price==-1 /*|| HOP_price==-1*/)
           {
             downtrend=false;
             ObjectSet(current_chart+"_LOP",OBJPROP_WIDTH,1);   
             return -1; // this part is necessary in case periods_pivot_price ever returns 0
           }
         else retracement_pts=NormalizeDouble(range_pts*retracement_percent,digits);
        }
       if(current_bid<LOP_price) // if the low of the range was surpassed // TODO: use compare_doubles()?
         {
           // since the top of the range was surpassed, you have to reset the HOP. You might as well take this opportunity to take the period into account.
           range_pts=range_pts_calculation(OP_SELL,instrument);
           retracement_pts=NormalizeDouble(range_pts*retracement_percent,digits);          
           if(current_chart_matches)
             {
              if(ObjectFind(current_chart+"_retrace_LOP_down")<0)
                {
                  ObjectCreate(current_chart+"_retrace_LOP_down",OBJ_HLINE,0,TimeCurrent(),LOP_price);
                  ObjectSet(current_chart+"_retrace_LOP_down",OBJPROP_COLOR,clrYellow);
                  ObjectSet(current_chart+"_retrace_LOP_down",OBJPROP_STYLE,STYLE_DASH);
                }
              if(ObjectFind(current_chart+"_retrace_HOP_down")<0)
                {
                  ObjectCreate(current_chart+"_retrace_HOP_down",OBJ_HLINE,0,TimeCurrent(),LOP_price+retracement_pts);
                  ObjectSet(current_chart+"_retrace_HOP_down",OBJPROP_COLOR,clrYellow);
                  ObjectSet(current_chart+"_retrace_HOP_down",OBJPROP_STYLE,STYLE_DASH);
                }
              ObjectSet(current_chart+"_retrace_LOP_down",OBJPROP_PRICE1,LOP_price);
              ObjectSet(current_chart+"_retrace_HOP_down",OBJPROP_PRICE1,LOP_price+retracement_pts);       
             }
           return -1;
         } 
       else if(current_bid-LOP_price>=retracement_pts) // if the pip move meets or exceed the ADR_Pips in points, return the current bid. Note: this will return true over and over again // TODO: use compare_doubles()?
         {
           // since the bottom of the range was surpassed and a pending order would be created, this is a good opportunity to update the range in the period since you can't just leave it as the static value constantly
           range_pts=range_pts_calculation(OP_SELL,instrument);
           retracement_pts=NormalizeDouble(range_pts*retracement_percent,digits);

           if(current_bid-LOP_price>=retracement_pts) // TODO: use compare_doubles()?
             {
               if(current_chart_matches)
                 {
                  if(ObjectFind(current_chart+"_retrace_LOP_down")<0)
                    {
                      ObjectCreate(current_chart+"_retrace_LOP_down",OBJ_HLINE,0,TimeCurrent(),LOP_price);
                      ObjectSet(current_chart+"_retrace_LOP_down",OBJPROP_COLOR,clrYellow);
                      ObjectSet(current_chart+"_retrace_LOP_down",OBJPROP_STYLE,STYLE_DASH);
                    }
                  if(ObjectFind(current_chart+"_retrace_HOP_down")<0)
                    {
                      ObjectCreate(current_chart+"_retrace_HOP_down",OBJ_HLINE,0,TimeCurrent(),LOP_price+retracement_pts);
                      ObjectSet(current_chart+"_retrace_HOP_down",OBJPROP_COLOR,clrYellow);
                      ObjectSet(current_chart+"_retrace_HOP_down",OBJPROP_STYLE,STYLE_DASH);
                    }
                  ObjectSet(current_chart+"_retrace_LOP_down",OBJPROP_PRICE1,LOP_price);
                  ObjectSet(current_chart+"_retrace_HOP_down",OBJPROP_PRICE1,LOP_price+retracement_pts);       
                 }
               //Print("downtrend trade should trigger");
               if(get_current_bid_instead) 
                 {
                   return current_bid; // check if it is actually true by taking the new calculation of Low Of Period into account
                 }
               else 
                 {
                   double met_price=LOP_price+retracement_pts;
                   return met_price;
                 }
             }
           else return -1;
         }         
       else return -1;
      }
    else
      {
        if(downtrend==false && current_chart_matches)
          {
            ObjectDelete(current_chart+"_retrace_HOP_down");
            ObjectDelete(current_chart+"_retrace_LOP_down");
          }
        return -1;
      }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double range_pts_calculation(int cmd,string instrument)
  {
    if(cmd==OP_BUY)
      {
        HOP_price=periods_pivot_price(SELLING_MODE,instrument);
        return(HOP_price-LOP_price);
      }
    if(cmd==OP_SELL)
      {
        LOP_price=periods_pivot_price(BUYING_MODE,instrument);
        return(HOP_price-LOP_price);
      }
    else return -1;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double uptrend_ADR_threshold_met_price(string instrument,bool get_current_bid_instead=false)
  {
    static double LOP=0; // Low Of Period
    double current_bid=MarketInfo(instrument,MODE_BID); // TODO: always make sure RefreshRates() was called before. In this case, it was called before running this function.
    string current_chart=Symbol();
    bool current_chart_matches=(current_chart==instrument);
    
    if(LOP==0) LOP=periods_pivot_price(BUYING_MODE,instrument);
    if(current_chart==instrument)
      {
        if(ObjectFind(current_chart+"_LOP")<0)
          {
            ObjectCreate(current_chart+"_LOP",OBJ_HLINE,0,TimeCurrent(),LOP);
            ObjectSet(current_chart+"_LOP",OBJPROP_COLOR,clrWhite);
          }
        if(ObjectFind(current_chart+"_HOP")<0)
          {
            ObjectCreate(current_chart+"_HOP",OBJ_HLINE,0,TimeCurrent(),LOP+ADR_pts);
            ObjectSet(current_chart+"_HOP",OBJPROP_COLOR,clrWhite);
          }     
      } 
    if(LOP==-1) // this part is necessary in case periods_pivot_price ever returns 0
      {
        return -1;
      }
    else if(current_bid<LOP) // if the low of the range was surpassed // TODO: use compare_doubles()?
    {
      // since the bottom of the range was surpassed, you have to reset the LOP. You might as well take this opportunity to take the period into account.
      LOP=periods_pivot_price(BUYING_MODE,instrument);
      uptrend=false;
      ObjectSet(current_chart+"_HOP",OBJPROP_WIDTH,1); 
  
      if(current_chart_matches)
        {
          ObjectSet(current_chart+"_LOP",OBJPROP_PRICE1,LOP);
          ObjectSet(current_chart+"_HOP",OBJPROP_PRICE1,LOP+ADR_pts);        
        }
      return -1;
    } 
    else if(current_bid-LOP>=ADR_pts) // if the pip move meets or exceed the ADR_Pips in points, return the current bid. Note: this will return true over and over again // TODO: use compare_doubles()?
      {
        // since the top of the range was surpassed and a pending order would be created, this is a good opportunity to update the LOP since you can't just leave it as the static value constantly
        LOP=periods_pivot_price(BUYING_MODE,instrument);
        if(current_chart_matches)
          {
            ObjectSet(current_chart+"_LOP",OBJPROP_PRICE1,LOP);
            ObjectSet(current_chart+"_HOP",OBJPROP_PRICE1,LOP+ADR_pts);     
          }
        if(current_bid-LOP>=ADR_pts) // TODO: use compare_doubles()?
          {
            uptrend=true;
            downtrend=false;
            ObjectSet(current_chart+"_HOP",OBJPROP_WIDTH,4);
            ObjectSet(current_chart+"_LOP",OBJPROP_WIDTH,1);
            LOP_price=LOP; // assign LOP to the global variable LOP_price so that if there is a retracement that meets the retracement threshold, this price can be used to calculate the range
            if(get_current_bid_instead) 
              {
                return current_bid; // check if it is actually true by taking the new calculation of Low Of Period into account
              }
            else 
              {
                double met_price=LOP+ADR_pts;
                return met_price;
              }
          }
        else return -1;
      }         
    else return -1;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double downtrend_ADR_threshold_met_price(string instrument,bool get_current_bid_instead=false)
  {
    static double HOP=0; // High Of Period
    double current_bid=MarketInfo(instrument,MODE_BID); // TODO: always make sure RefreshRates() was called before. In this case, it was called before running this function.
    string current_chart=Symbol();
    bool current_chart_matches=(current_chart==instrument);
    
    if(HOP==0) HOP=periods_pivot_price(SELLING_MODE,instrument);
    if(current_chart==instrument)
      {
        if(ObjectFind(current_chart+"_HOP")<0)
          {
            ObjectCreate(current_chart+"_HOP",OBJ_HLINE,0,TimeCurrent(),HOP);
            ObjectSet(current_chart+"_HOP",OBJPROP_COLOR,clrWhite);
          }
        if(ObjectFind(current_chart+"_LOP")<0)
          {
            ObjectCreate(current_chart+"_LOP",OBJ_HLINE,0,TimeCurrent(),HOP-ADR_pts);
            ObjectSet(current_chart+"_LOP",OBJPROP_COLOR,clrWhite);
          }
      }
    if(HOP==-1) // this part is necessary in case periods_pivot_price ever returns 0
      {
        return -1;
      }
    else if(current_bid>HOP) // if the low of the range was surpassed // TODO: use compare_doubles()?
      {
        // since the bottom of the range was surpassed, you have to reset the LOP. You might as well take this opportunity to take the period into account.
        HOP=periods_pivot_price(SELLING_MODE,instrument);
        downtrend=false;
        ObjectSet(current_chart+"_LOP",OBJPROP_WIDTH,1);
        
        if(current_chart_matches)
          {
            ObjectSet(current_chart+"_HOP",OBJPROP_PRICE1,HOP);
            ObjectSet(current_chart+"_LOP",OBJPROP_PRICE1,HOP-ADR_pts);       
          }
        return -1;
      } 
    else if(HOP-current_bid>=ADR_pts) // if the pip move meets or exceed the ADR_Pips in points, return the current bid. Note: this will return true over and over again // TODO: use compare_doubles()?
      {
        // since the top of the range was surpassed and a pending order would be created, this is a good opportunity to update the LOP since you can't just leave it as the static value constantly
        HOP=periods_pivot_price(SELLING_MODE,instrument);
        if(current_chart_matches)
          {
            ObjectSet(current_chart+"_HOP",OBJPROP_PRICE1,HOP);
            ObjectSet(current_chart+"_LOP",OBJPROP_PRICE1,HOP-ADR_pts); 
          }
        if(HOP-current_bid>=ADR_pts) // TODO: use compare_doubles()?
        {
          downtrend=true;
          uptrend=false;
          ObjectSet(current_chart+"_HOP",OBJPROP_WIDTH,1); 
          ObjectSet(current_chart+"_LOP",OBJPROP_WIDTH,4); 
          
          HOP_price=HOP; // assign HOP to the global variable HOP_price so that if there is a retracement that meets the retracement threshold, this price can be used to calculate the range
          if(get_current_bid_instead) 
            {
              return current_bid; // check if it is actually true by taking the new calculation of Low Of Period into account
            }
          else 
            {
              double met_price=HOP-ADR_pts;
              return met_price;
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
bool modify_order(int ticket,double sl_pts,double tp_pts=-1,datetime expire=-1,double entry_price=-1,color a_color=clrNONE)
  {
   bool result=false;
   if(OrderSelect(ticket,SELECT_BY_TICKET))
     {
      int digits=(int)MarketInfo(OrderSymbol(),MODE_DIGITS); // The count of digits after the decimal point.
      if(sl_pts==-1) sl_pts=OrderStopLoss(); // if stoploss is not changed from the default set in the argument
      else sl_pts=NormalizeDouble(sl_pts,digits);
      if(tp_pts==-1) tp_pts=OrderTakeProfit(); // if takeprofit is not changed from the default set in the argument
      else tp_pts=NormalizeDouble(tp_pts,digits); // it needs to be normalized since you calculated it yourself to prevent errors when modifying an order
      if(OrderType()<=1) // if it IS NOT a pending order
        {
        // to prevent Error Code 1, check if there was a change
        // compare_doubles returns 0 if the doubles are equal
         if(compare_doubles(sl_pts,OrderStopLoss(),digits)==0 && 
            compare_doubles(tp_pts,OrderTakeProfit(),digits)==0)
            return true; //terminate the function
         entry_price=OrderOpenPrice();
        }
      else if(OrderType()>1) // if it IS a pending order
        {
         if(entry_price==-1) // it is -1 if there was no entry_price sent to this function (the 4th parameter)
            entry_price=OrderOpenPrice();
         else entry_price=NormalizeDouble(entry_price,digits); // it needs to be normalized since you calculated it yourself to prevent errors when modifying an order
         // to prevent error code 1, check if there was a change
         // compare_doubles returns 0 if the doubles are equal
         if(compare_doubles(entry_price,OrderOpenPrice(),digits)==0 && 
            compare_doubles(sl_pts,OrderStopLoss(),digits)==0 && 
            compare_doubles(tp_pts,OrderTakeProfit(),digits)==0 && 
            expire==OrderExpiration())
            return true; //terminate the function
        }
      result=OrderModify(ticket,entry_price,sl_pts,tp_pts,expire,a_color);
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// check for errors before modifying the order
bool try_to_modify_order(int ticket,double sl_pts,int _retries=3,double tp_pts=-1,datetime expire=-1,double entryPrice=-1,color a_color=clrNONE,int sleep_milisec=500) // TODO: should the defaults really be -1?
  {
   bool result=false;
   if(ticket>0)
     {
      for(int i=0;i<_retries;i++)
        {
         if(!IsConnected()) Print("The EA can't modify ticket ",IntegerToString(ticket)," because there is no internet connection.");
         else if(!IsExpertEnabled()) Print("The EA can't modify ticket ",IntegerToString(ticket)," because EAs are not enabled in the trading platform.");
         else if(IsTradeContextBusy()) Print("The EA can't modify ticket ",IntegerToString(ticket)," because The trade context is busy.");
         else if(!IsTradeAllowed()) Print("The EA can't modify ticket ",IntegerToString(ticket)," because the trade is not allowed in the trading platform.");
         else result=modify_order(ticket,sl_pts,tp_pts,expire,entryPrice,a_color); // entryPrice could be -1 if there was no entryPrice sent to this function
         if(result)
            break;
         Sleep(sleep_milisec);
      // TODO: setup an email and SMS alert.
     Print(OrderSymbol()," , ",WindowExpertName(),", An order was attempted to be modified but it did not succeed. Last Error: (",IntegerToString(GetLastError(),0),"), Retry: ",IntegerToString(i,0),"/"+IntegerToString(retries));
     Alert(OrderSymbol()," , ",WindowExpertName(),", An order was attempted to be modified but it did not succeed. Check the Journal tab of the Navigator window for errors.");
        }
     }
   else
     {   
      Print(OrderSymbol()," , ",WindowExpertName(),", Modifying the order was not successfull. The ticket couldn't be selected.");
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
bool try_to_exit_order(int ticket,int max_slippage_pips,int _retries=3,color a_color=clrNONE,int sleep_milisec=500)
  {
   bool result=false;
   
   for(int i=0;i<_retries;i++)
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
            try_to_exit_order(OrderTicket(),exiting_max_slippage_pips,retries);
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
    int digits=(int)MarketInfo(instrument,MODE_DIGITS);
    
    if(refresh_rates) RefreshRates();
    if(spread_pts_provided==0)
      {
        double point=MarketInfo(instrument,MODE_POINT);
        _spread_pts=NormalizeDouble(MarketInfo(instrument,MODE_SPREAD)*point*point_multiplier,digits); //  I put this check here because the rates were just refreshed.
      }
    else
      {
        _spread_pts=spread_pts_provided;
      }
    if(_based_on_raw_ADR==true && change_ADR_percent!=0)
      {
        double max_spread=NormalizeDouble((ADR_pts-(ADR_pts*change_ADR_percent))*_max_spread_percent,digits);
        //Print("max_spread1: ",DoubleToString(max_spread,digits));
        if(compare_doubles(_spread_pts,max_spread,digits)<=0) 
          {
            //Print("_spread_pts1: ",DoubleToString(_spread_pts,digits));
            return true; // Keeps the EA from entering trades when the spread is too wide for market orders (but not pending orders). Note: It may never enter on exotic currencies (which is good automation).
          }
      }
    else
      {
        double max_spread=NormalizeDouble(ADR_pts*_max_spread_percent,digits);
        //Print("max_spread2: ",DoubleToString(max_spread,digits));
        if(compare_doubles(_spread_pts,max_spread,digits)<=0)
          {
            //Print("_spread_pts2: ",DoubleToString(_spread_pts,digits));
            return true; // Keeps the EA from entering trades when the spread is too wide for market orders (but not pending orders). Note: It may never enter on exotic currencies (which is good automation).
          } 
      }
    //Print("acceptable_spread returned false");
    return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculate_avg_spread_yesterday(string instrument)
  {
   int digits=(int)MarketInfo(instrument,MODE_DIGITS);
   double point=MarketInfo(instrument,MODE_POINT);
    /*datetime new_server_day=-1;
    datetime end_server_day=-1;
    double spread_total=0;
    
    if(TimeDayOfWeek(iTime(instrument,PERIOD_D1,1))!=0) // if not Sunday, analyze yesterday
      {
        new_server_day=iTime(instrument,PERIOD_D1,1);
        end_server_day=iTime(instrument,PERIOD_D1,0)-(5*60);
      }    
    else // if Sunday, analyze the day before yesterday
      {
        new_server_day=iTime(instrument,PERIOD_D1,2);
        end_server_day=iTime(instrument,PERIOD_D1,1)-(5*60); // the start of the last bar of the specific day
      }
    
    int new_server_day_bar=iBarShift(instrument,PERIOD_M5,new_server_day,false);
    int end_server_day_bar=iBarShift(instrument,PERIOD_M5,end_server_day,false);
    
    for(int i=new_server_day_bar;i>=end_server_day_bar;i--) // 288 M5 bars in 24 hours
      {
        datetime bar_time=iTime(instrument,PERIOD_M5,i);
        // convert bar_time
        
        bool in_time_range=in_time_range(bar_time,start_time_hour,start_time_minute,end_time_hour,end_time_minute,gmt_hour_offset);
        if(in_time_range)
          {
            // TODO: you won't be able to get the average spread from the previous day because it is not possible. Try to code a spread history indicator and get it from there.
            double spread=NormalizeDouble(MarketInfo(instrument,MODE_SPREAD)*point*point_multiplier,Digits); // divide by 10
            spread_total+=spread;
          }
      }
    return NormalizeDouble(spread_total/(new_server_day_bar-end_server_day_bar),Digits); // return the average spread*/
    
    double avg_spread_yesterday=NormalizeDouble(MarketInfo(instrument,MODE_SPREAD)*point*point_multiplier,digits); // this line is temporary until I find a way to get spread history
    //Print("calculate_avg_spread_yesterday() returns: ",avg_spread_yesterday);
    return avg_spread_yesterday;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void try_to_enter_order(ENUM_ORDER_TYPE type,int magic,int max_slippage_pips,string instrument)
  {
   double pending_order_distance_pts=0; // keep at 0
   double periods_pivot_price;
   color arrow_color;
   int digits=(int)MarketInfo(instrument,MODE_DIGITS);
   double point=MarketInfo(instrument,MODE_POINT);
   double takeprofit_pts=0,stoploss_pts=0;
   double _pullback_percent=pullback_percent;
   double _retracement_percent=retracement_percent;
   double periods_range_pts=ADR_pts; // keep at ADR_pts

   if(reverse_trade_direction) // TODO: should this code be run before or after range_pts_calculation is run? I think before because the periods_range_pts need to be calculated as if it was not a reverse trade.
     {
       if(type==OP_BUY) type=OP_SELL;
       else if(type==OP_SELL) type=OP_BUY;
     }
   if(_pullback_percent<0) 
     {
       Print("Error: pullback_percent cannot be less than 0");
       return;
     }
   if(_pullback_percent==NULL) 
     {
       _pullback_percent=0;
     }
   if(_retracement_percent>0)
     {
       periods_range_pts=range_pts_calculation(type,instrument); // TODO: is it okay that the periods_range_pts is calculated with the type before the reverse_trade_direction code runs?
       if(_pullback_percent>0) pending_order_distance_pts=NormalizeDouble((_retracement_percent+_pullback_percent)*periods_range_pts,digits); 
     }
   else 
     {
       if(_pullback_percent>0) pending_order_distance_pts=NormalizeDouble(_pullback_percent*periods_range_pts,digits);
     }
   //Print("try_to_enter_order(): distance_pts: ",DoubleToString(pullback_distance_pts));
   
   if(type==OP_BUY)
     {
      //if(!long_allowed) return;
      if(reverse_trade_direction) arrow_color=clrRed;
      else arrow_color=clrGreen;
      if(_retracement_percent>0 && LOP_price>0) periods_pivot_price=LOP_price;
      else periods_pivot_price=periods_pivot_price(BUYING_MODE,instrument);
     }
   else if(type==OP_SELL)
     {
      ///if(!short_allowed) return;
      if(reverse_trade_direction) arrow_color=clrGreen;
      else arrow_color=clrRed;
      if(_retracement_percent>0 && HOP_price>0) periods_pivot_price=HOP_price;
      else periods_pivot_price=periods_pivot_price(SELLING_MODE,instrument);
     }
   else return;
   
   RefreshRates();
   double spread_pts=NormalizeDouble(MarketInfo(instrument,MODE_SPREAD)*point*point_multiplier,digits);
   takeprofit_pts=NormalizeDouble(periods_range_pts*takeprofit_percent,digits); // do not put this calculation into the parameter of the check_for_entry_errors function // TODO: In your trading rules, should you put this line above "periods_range_pts=MathMin(periods_range_pts,ADR_pts);"?
   if(prevent_ultrawide_stoploss) periods_range_pts=MathMin(periods_range_pts,ADR_pts); // Does not allow the stoploss and takeprofit to be more than ADR_pts. This line must go above the lots, takeprofit_pts and stoploss_pts calculations.
   double lots=calculate_lots(money_management,periods_range_pts,risk_percent_per_range,spread_pts,instrument);
   stoploss_pts=NormalizeDouble((periods_range_pts*stoploss_percent)-pending_order_distance_pts-(_retracement_percent*periods_range_pts),digits);
   
   int ticket=check_for_entry_errors(instrument,
                                     type,
                                     lots,
                                     pending_order_distance_pts, // the distance_pips you are sending to the function should always be positive
                                     periods_pivot_price,
                                     stoploss_pts,
                                     takeprofit_pts,
                                     max_slippage_pips,
                                     spread_pts,
                                     periods_range_pts,
                                     WindowExpertName(),
                                     magic,
                                     int(pending_order_expire*3600),
                                     arrow_color,
                                     market_exec,
                                     retries);
   if(ticket>0) cleanup_risky_pending_orders();
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
string generate_comment(string instrument,int magic,double sl_pts, double tp_pts,double spread_pts) // TODO: Add more user parameter settings for the order to the message so they know what settings generated the results.
  {
    string comment;
    return comment=StringConcatenate("EA: ",WindowExpertName(),"Magic#: ",IntegerToString(magic),", CCY Pair: ",instrument," Requested TP: ",DoubleToStr(tp_pts)," Requested SL: ",DoubleToStr(sl_pts),"Spread slighly before order: ",DoubleToStr(spread_pts));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+ 
int check_for_entry_errors(string instrument,int cmd,double lots,double _distance_pts,double periods_pivot_price,double sl_pts,double tp_pts,int max_slippage,double spread_points,double range_pts,string _EA_name=NULL,int magic=0,int expire=0,color a_clr=clrNONE,bool market=false,int _retries=3,int sleep_milisec=500)
  {
   int ticket=0;
   for(int i=0;i<_retries;i++)
     {
      if(IsStopped()) Print("The EA can't enter a trade because the EA was stopped.");
      else if(!IsConnected()) Print("The EA can't enter a trade because there is no internet connection.");
      else if(!IsExpertEnabled()) Print("The EA can't enter a trade because EAs are not enabled in trading platform.");
      else if(IsTradeContextBusy()) Print("The EA can't enter a trade because the trade context is busy.");
      else if(!IsTradeAllowed()) Print("The EA can't enter a trade because the trade is not allowed in the trading platform.");
      else ticket=send_and_get_order_ticket(instrument,cmd,lots,_distance_pts,periods_pivot_price,sl_pts,tp_pts,max_slippage,spread_points,range_pts,_EA_name,magic,expire,a_clr,market);
      if(ticket>0) break;
      else
      { 
        // TODO: setup an email and SMS alert.
        Print(instrument," , ",WindowExpertName(),": A ",cmd," order was attempted but it did not succeed. If there are no errors here, market factors may not have met the code's requirements within the send_and_get_order_ticket function. Last Error:, (",IntegerToString(GetLastError(),0),"), Retry: "+IntegerToString(i,0),"/"+IntegerToString(retries));
        //Alert(instrument," , ",WindowExpertName(),": A ",cmd," order was attempted but it did not succeed. Check the Journal tab of the Navigator window for errors.");
      }
      Sleep(sleep_milisec);
     }
   Print("ticket: ",IntegerToString(ticket));
   return ticket;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void generate_spread_not_acceptable_message(double spread_pts,string instrument)
  {
    double percent_allows_trading=NormalizeDouble(((average_spread_yesterday-(ADR_pts*max_spread_percent))/ADR_pts)+max_spread_percent,3);
    string message=StringConcatenate (instrument," this signal to enter can't be sent because the current spread does not meet your max_spread_percent (",
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
// Documentation: Requirements and Limitions in Making Trades https://book.mql4.com/appendix/limits
int send_and_get_order_ticket(string instrument,int cmd,double lots,double _distance_pts,double periods_pivot_price,double sl_pts,double tp_pts,int max_slippage,double spread_pts,double range_pts,string _EA_name=NULL,int magic=0,int expire=0,color a_clr=clrNONE,bool _market_exec=false) // the "market" argument is to make this function compatible with brokers offering market execution. By default, it uses instant execution.
  {
   double entry_price=0, price_sl=0, price_tp=0;
   double point=MarketInfo(instrument,MODE_POINT);
   double min_distance_pts=MarketInfo(instrument,MODE_STOPLEVEL)*point*point_multiplier;
   int digits=(int)MarketInfo(instrument,MODE_DIGITS);
   //RefreshRates(); // may not be necessary since rates were extremely recently refreshed in try_to_enter_order function
   double current_ask=MarketInfo(instrument,MODE_ASK);
   double current_bid=MarketInfo(instrument,MODE_BID);
   datetime expire_time=0; // 0 means there is no expiration time for a pending order
   int order_type=-1; // -1 means there is no order because actual orders are >=0
   bool instant_exec=!_market_exec;
   //Print("send_and_get_order_ticket(): tp_pts before adding spread_pts: ",DoubleToString(tp_pts)); 
   
   tp_pts+=spread_pts; // increase the take profit so the user can get the full pips of profit they wanted if the take profit price is hit
   //if(range_pts>ADR_pts) _ADR_pts=range_pts;
   
   Print("send_and_get_order_ticket(): lots: ",DoubleToString(lots));
   Print("send_and_get_order_ticket(): _distance_pts: ",DoubleToString(_distance_pts));
   Print("send_and_get_order_ticket(): min_distance_pts: ",DoubleToString(min_distance_pts));
   Print("send_and_get_order_ticket(): current_price: ",DoubleToString(current_bid));
   Print("send_and_get_order_ticket(): periods_pivot_price: ",DoubleToString(periods_pivot_price));
   Print("send_and_get_order_ticket(): max_slippage: ",IntegerToString(max_slippage));
   Print("send_and_get_order_ticket(): spread_pts: ",DoubleToString(spread_pts));
   Print("send_and_get_order_ticket(): tp_pts: ",DoubleToString(tp_pts));
   Print("send_and_get_order_ticket(): sl_pts: ",DoubleToString(sl_pts));
   Print("send_and_get_order_ticket(): magic: ",IntegerToString(magic));
   /*if(reverse_trade_direction)
     {
       if(cmd==OP_BUY) cmd=OP_SELL;
       else if(cmd==OP_SELL) cmd=OP_BUY;
     }*/
   bool is_acceptable_spread=acceptable_spread(instrument,max_spread_percent,based_on_raw_ADR,spread_pts,false);
   Print("send_and_get_order_ticket(): is_acceptable_spread: ",is_acceptable_spread);
   if(is_acceptable_spread==false) 
    {
      // Keeps the EA from entering trades when the spread is too wide for market orders (but not pending orders). Note: It may never enter on exotic currencies (which is good automation).
      generate_spread_not_acceptable_message(spread_pts,instrument);
      // TODO: create an alert informing the user that the trade was not executed because the spread was too wide
      return 0;
    }
   if(cmd==OP_BUY) // logic for long trades
     {
      if(_distance_pts>0) order_type=OP_BUYLIMIT;
      else if(_distance_pts==0) order_type=OP_BUY;
      else /*if(_distance_pts<0) order_type=OP_BUYSTOP*/ return 0;
      if(order_type==OP_BUYLIMIT)
        {
         if(periods_pivot_price<0) return 0;
         // get the Min to prevent Error 130 caused by the entry_price distance from the current price from being too small
         // this sets the entry_price for both instant and market executions
         if(reverse_trade_direction) entry_price=MathMin((periods_pivot_price+range_pts)-_distance_pts/*+average_spread_yesterday*/,current_bid-min_distance_pts); // setting the entry_price this way prevents setting your limit and stop orders based on the current price (which would have caused inaccurate setting of prices)
         else entry_price=MathMin((periods_pivot_price+range_pts)-_distance_pts+average_spread_yesterday,current_ask-min_distance_pts) /*(adding average_spread_yesterday should make it close to MODE_ASK which is similar to what the immediate buy order does)*/; // setting the entry_price this way prevents setting your limit and stop orders based on the current price (which would have caused inaccurate setting of prices)
         //Print("send_and_get_order_ticket(): periods_pivot_price-Bid: ",DoubleToString(periods_pivot_price-Bid));
         //Print("send_and_get_order_ticket(): range_pts: ",DoubleToString(_ADR_pts));
         //Print("send_and_get_order_ticket(): average_spread_yesterday: ",DoubleToString(average_spread_yesterday));         
        }
      else if(order_type==OP_BUY)
        {
          if(reverse_trade_direction) entry_price=current_bid;
          else entry_price=current_ask;
          //Print("send_and_get_order_ticket(): entry_price: ",DoubleToString(entry_price));
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
      if(_distance_pts>0) order_type=OP_SELLLIMIT;
      else if(_distance_pts==0) order_type=OP_SELL;
      else /*if(_distance_pts<0) order_type=OP_SELLSTOP*/ return 0;
      if(order_type==OP_SELLLIMIT)
        {
         if(periods_pivot_price<0) return 0;
         // get the Max to prevent Error 130 caused by the entry_price distance from the current price from being too small
         // this sets the entry_price for both instant and market executions
         if(reverse_trade_direction) entry_price=MathMax((periods_pivot_price-range_pts)+_distance_pts+average_spread_yesterday,current_ask+min_distance_pts); // setting the entry_price this way prevents setting your limit and stop orders based on the current price (which would have caused inaccurate setting of prices)
         else entry_price=MathMax((periods_pivot_price-range_pts)+_distance_pts/*-average_spread_yesterday*/,current_bid+min_distance_pts) /*(subtracting average_spread_yesterday should make it close to MODE_BID which is similar to what the immediate buy order does*/; // setting the entry_price this way prevents setting your limit and stop orders based on the current price (which would have caused inaccurate setting of prices)
        }
      else if(order_type==OP_SELL)
        {
          if(reverse_trade_direction) entry_price=current_ask;
          else entry_price=current_bid;     
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
    if(reverse_trade_direction)
      {
        // this only switches the takeprofit and stoploss prices for instant execution
        double new_price_sl=price_tp;
        double new_price_tp=price_sl;
        
        price_tp=new_price_tp;
        price_sl=new_price_sl;
        
        // this switches the order_type for both instant and market executions
        if(order_type==OP_BUYLIMIT) order_type=OP_SELLLIMIT;
        else if(order_type==OP_SELLLIMIT) order_type=OP_BUYLIMIT;
        if(order_type==OP_BUY) order_type=OP_SELL;
        else if(order_type==OP_SELL) order_type=OP_BUY;
      }
    if(order_type<0) return 0; // if there is no order
    else if(order_type==OP_BUY || order_type==OP_SELL) expire_time=0; // if it is NOT a pending order, set the expire_time to 0 because it cannot have an expire_time
    else if(expire>0) expire_time=(datetime)MarketInfo(instrument,MODE_TIME)+expire; // expiration of the order = current time + expire time
    string generated_comments=generate_comment(instrument,magic,sl_pts,tp_pts,spread_pts);
    
    if(instant_exec)
      {
        //Print("instant_exec expire_time=",expire_time);
        Print("send_and_get_order_ticket(): entry_price: ",DoubleToString(entry_price,digits));        
        Print("send_and_get_order_ticket(): current_bid: ",DoubleToString(current_bid,digits));
        Print("send_and_get_order_ticket(): current_ask: ",DoubleToString(current_ask,digits));
        Print("send_and_get_order_ticket(): price_sl: ",DoubleToString(price_sl,digits));
        Print("send_and_get_order_ticket(): price_tp: ",DoubleToString(price_tp,digits));
        Print("send_and_get_order_ticket(): price_tp-entry_price: ",DoubleToString(MathAbs(price_tp-entry_price),digits));
        Print("send_and_get_order_ticket(): price_sl-entry_price: ",DoubleToString(MathAbs(price_sl-entry_price),digits));
        Print("instrument: ",instrument,", ordertype: ",order_type,", lots: ",lots,", entryprice: ",DoubleToString(entry_price),", max_slippage: ",IntegerToString(max_slippage),", price_sl: ",DoubleToString(price_sl),", price_tp: ",price_tp,", magic: ",magic,", expire_time: ",expire_time);
        
        if(order_type==OP_BUYLIMIT && reverse_trade_direction==false)
          {
            if(compare_doubles(current_ask-entry_price,min_distance_pts,digits)==-1) Print("If BuyLimit, this will result in an Open Price error because current_ask-entry_price(",DoubleToString(current_ask-entry_price),")<min_distance_pips");
            if(compare_doubles(entry_price-price_sl,min_distance_pts,digits)==-1) Print("If BuyLimit, this will result in an Stoploss error because entry_price-price_sl(",DoubleToString(entry_price-price_sl),")<min_distance_pips");
            if(compare_doubles(price_tp-entry_price,min_distance_pts,digits)==-1) Print("If BuyLimit, this will result in an Takeprofit error because price_tp-entry_price(",DoubleToString(price_tp-entry_price),")<min_distance_pips");
          }
        int ticket=OrderSend(instrument,order_type,lots,NormalizeDouble(entry_price,digits),max_slippage,NormalizeDouble(price_sl,digits),NormalizeDouble(price_tp,digits),generated_comments,magic,expire_time,a_clr);
        if(ticket>0)
          {
            if(OrderSelect(ticket,SELECT_BY_TICKET))
              {
                if(order_type==OP_BUY || order_type==OP_BUYLIMIT)
                  {
                    uptrend_trade_happened_last=true;
                    downtrend_trade_happened_last=false;
                  }
                else if(order_type==OP_SELL || order_type==OP_SELLLIMIT)
                  {
                    uptrend_trade_happened_last=false;
                    downtrend_trade_happened_last=true;
                  }
              }
          }
        Print("returning instant_exec ticket");
        return ticket;
      }
    else if(_market_exec) // If the user wants market execution (which does NOT allow them to input the sl and tp prices), this will calculate the stoploss and takeprofit AFTER the order to buy or sell is sent.
     {
      //Print("market_exec expire_time=",expire_time);
      if(reverse_trade_direction)
        {
          double new_sl_pts=tp_pts;
          double new_tp_pts=sl_pts;
          tp_pts=new_tp_pts;
          sl_pts=new_sl_pts;
        }
      int ticket=OrderSend(instrument,order_type,lots,NormalizeDouble(entry_price,digits),max_slippage,0,0,generated_comments,magic,expire_time,a_clr);
      if(ticket>0) // if there is a valid ticket
        {
         if(OrderSelect(ticket,SELECT_BY_TICKET))
           {
            if(order_type==OP_BUY || order_type==OP_BUYLIMIT)
              {
               if(sl_pts>0) 
                {
                  if(compare_doubles(sl_pts,min_distance_pts,digits)==-1) price_sl=OrderOpenPrice()-min_distance_pts; 
                  else price_sl=OrderOpenPrice()-sl_pts;
                }
               if(compare_doubles(tp_pts,spread_pts,digits)==1)
                 {
                  if(compare_doubles(tp_pts,min_distance_pts,digits)==-1) price_tp=OrderOpenPrice()+min_distance_pts;                   
                  else price_tp=OrderOpenPrice()+tp_pts;
                 }
               uptrend_trade_happened_last=true;
               downtrend_trade_happened_last=false;
              }
            else if(order_type==OP_SELL || order_type==OP_SELLLIMIT)
              {
               if(sl_pts>0) 
                 {
                  if(compare_doubles(sl_pts,min_distance_pts,digits)==-1) price_sl=OrderOpenPrice()+min_distance_pts;
                  price_sl=OrderOpenPrice()+sl_pts;
                 }
               if(compare_doubles(tp_pts,spread_pts,digits)==1)
                 {
                  if(compare_doubles(tp_pts,min_distance_pts,digits)==-1) price_tp=OrderOpenPrice()-min_distance_pts; 
                  price_tp=OrderOpenPrice()-tp_pts;
                 }
               uptrend_trade_happened_last=false;
               downtrend_trade_happened_last=true;
              }
            Print("send_and_get_order_ticket(): price_sl: ",DoubleToString(price_sl,digits));
            Print("send_and_get_order_ticket(): price_tp: ",DoubleToString(price_tp,digits));
            bool result=try_to_modify_order(ticket,NormalizeDouble(price_sl,digits),retries,NormalizeDouble(price_tp,digits),expire_time);
           }
        }
      Print("returning market_exec ticket");
      return ticket;
     }
    else 
      {
        Print("send_and_get_ticket: returned 0");
        return 0;
      } 
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculate_lots(ENUM_MM method,double range_pts,double _risk_percent_per_ADR,double spread_pts,string instrument)
  {
    double points=0;
    double _stoploss_percent=stoploss_percent;
    int digits=(int)MarketInfo(instrument,MODE_DIGITS);

    if(method==MM_RISK_PERCENT_PER_ADR)
      points=NormalizeDouble(range_pts+spread_pts,digits); // Increase the Average Daily (pip) Range by adding the average (pip) spread because it is additional pips at risk everytime a trade is entered. As a result, the lots that get calculated will be lower (which will slightly reduce the risk).
    else if(range_pts>0 && _stoploss_percent>0)
      points=NormalizeDouble((range_pts*_stoploss_percent)+spread_pts,digits); // it could be 0 if stoploss_percent is set to 0 
    else 
      points=NormalizeDouble(range_pts+spread_pts,digits);

    double lots=get_lots(method,
                        instrument,
                        _risk_percent_per_ADR,
                        points,
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
// TODO: is it pips or points that the 4th parameter actually needs?
double get_lots(ENUM_MM method,string instrument,double _risk_percent_per_ADR,double pts,double risk_mm1_percent/*,double lots_mm2,double per_mm2,double risk_mm3,double risk_mm4*/)
  {
   double tick_value=MarketInfo(instrument,MODE_TICKVALUE);
   double point=MarketInfo(instrument,MODE_POINT);
   double lots=0;
   double balance=0;
   
   if(compound_balance) balance=AccountBalance();
   else balance=5000;
    
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
   lots=NormalizeDouble(lots*point,lot_digits); // TODO: multiply by point?
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
void trailingstop_check_order(int ticket,double _threshold_percent,double _step_percent,bool same_stoploss)
  {
   if(ticket<=0) return;
   if(!OrderSelect(ticket,SELECT_BY_TICKET)) return;
   int digits=(int) MarketInfo(OrderSymbol(),MODE_DIGITS);
   double current_sl=OrderStopLoss();
   double trail_pts;
   double order_sl_pts=ADR_pts;
   
   if(retracement_percent>0) order_sl_pts=MathAbs(current_sl-OrderOpenPrice());
   if(compare_doubles(order_sl_pts,ADR_pts,digits)==-1) order_sl_pts=ADR_pts;
   if(same_stoploss) trail_pts=NormalizeDouble(order_sl_pts-(order_sl_pts*pullback_percent),digits);
   else trail_pts=order_sl_pts;

   if(OrderType()==OP_BUY)
     {
      if(current_sl-OrderOpenPrice()>=0) return; // Turn off trailing stop if the stoploss is at breakeven or above. This line should be above all the calculations. If it is true, all those calculations do not need to be done.
      double threshold_pts=NormalizeDouble(_threshold_percent*(takeprofit_percent*order_sl_pts),digits);
      double step_pts=NormalizeDouble(_step_percent*(takeprofit_percent*order_sl_pts),digits);
      double moving_sl=OrderClosePrice()-trail_pts; // the current price - the trail in pips
      double thresholds_activation_price=OrderOpenPrice()+threshold_pts;
      double new_sl=thresholds_activation_price-trail_pts;
      double step_in_pts=moving_sl-current_sl; // keeping track of the distance between the potential stoploss and the current stoploss
      if(current_sl==0 || compare_doubles(new_sl,current_sl,digits)==1) // if there is no stoploss or the new trailing stoploss > the current stoploss
        {
         if(compare_doubles(OrderClosePrice(),thresholds_activation_price,digits)>=0) 
          {
           try_to_modify_order(ticket,new_sl,retries); // if price met the threshold, move the stoploss
           Print("1) previous sl: ",DoubleToStr(current_sl,digits),", new trailing sl: ",DoubleToStr(new_sl,digits));
          }
        }
      else if(compare_doubles(step_in_pts,step_pts,digits)>=0) try_to_modify_order(ticket,NormalizeDouble(moving_sl,digits),retries); // if price met the step, move the stoploss
     }
   else if(OrderType()==OP_SELL)
     {
      if(OrderOpenPrice()-current_sl>=0) return; // Turn off trailing stop if the stoploss is at breakeven or above. This line should be above all the calculations. If it is true, all those calculations do not need to be done.
      double threshold_pts=NormalizeDouble(_threshold_percent*(takeprofit_percent*order_sl_pts),digits);
      double step_pts=NormalizeDouble(_step_percent*(takeprofit_percent*order_sl_pts),digits);
      double moving_sl=OrderClosePrice()+trail_pts;
      double thresholds_activation_price=OrderOpenPrice()-threshold_pts;
      double new_sl=thresholds_activation_price+trail_pts;
      double step_in_pts=current_sl-moving_sl;
      if(current_sl==0 || compare_doubles(new_sl,current_sl,digits)==-1)
        {
         if(compare_doubles(OrderClosePrice(),thresholds_activation_price,digits)<=0) 
          {
           try_to_modify_order(ticket,new_sl,retries); 
           Print("2) previous sl: ",DoubleToStr(current_sl,digits),", new trailing sl: ",DoubleToStr(new_sl,digits)); 
          }
        }
      else if(compare_doubles(step_in_pts,step_pts,digits)>=0) 
        {
          try_to_modify_order(ticket,NormalizeDouble(moving_sl,digits),retries);
          Print("3) previous sl: ",DoubleToStr(current_sl,digits),", new trailing moving sl: ",DoubleToStr(moving_sl,digits)); 
        }
     }
   return;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void trailingstop_check_all_orders(double _threshold_percent,double _step_percent,int magic=-1,bool _same_stoploss=false)
  {
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS))
        {
         if(magic==-1 || magic==OrderMagicNumber())
            trailingstop_check_order(OrderTicket(),_threshold_percent,_step_percent,_same_stoploss);
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
bool breakeven_check_order(int ticket,double threshold_percent,double plus_percent) 
  {
   if(ticket<=0) return true; // if it is not a valid ticket
   if(!OrderSelect(ticket,SELECT_BY_TICKET)) return false; // if there is no ticket, it cannot be process so return false
   int digits=(int)MarketInfo(OrderSymbol(),MODE_DIGITS); // how many digit broker
   bool result=true; // initialize the variable result
   double plus_pts=0;
   double order_sl=OrderStopLoss();
   double order_sl_pts=ADR_pts; // keep at ADR_pts
   
   if(retracement_percent>0) order_sl_pts=MathAbs(order_sl-OrderOpenPrice());
   if(compare_doubles(order_sl_pts,ADR_pts,digits)==-1) order_sl_pts=ADR_pts;
   double threshold_pts=NormalizeDouble(threshold_percent*(takeprofit_percent*order_sl_pts),digits);
   
   if(plus_percent!=0) plus_pts=NormalizeDouble(plus_percent*(takeprofit_percent*order_sl_pts),digits);
   
   if(OrderType()==OP_BUY) // if it is a buy order
     {
      double new_sl=OrderOpenPrice()+plus_pts; // calculate the price of the new stoploss
      double point_gain=OrderClosePrice()-OrderOpenPrice(); // calculate how many points in profit the trade is in so far
      if(order_sl==0 || compare_doubles(new_sl,order_sl,digits)==1) // if there is no stoploss or the potential new stoploss is greater than the current stoploss
         if(compare_doubles(point_gain,threshold_pts,digits)>=0) // if the profit in points so far > provided threshold, then set the order to breakeven
           {
            result=try_to_modify_order(ticket,NormalizeDouble(new_sl,digits),retries);
            Print("previous sl: ",DoubleToStr(order_sl,digits),", new breakeven sl: ",DoubleToStr(new_sl,digits));         
           }
     }
   else if(OrderType()==OP_SELL)
     {
      double new_sl=OrderOpenPrice()-plus_pts;
      double point_gain=OrderOpenPrice()-OrderClosePrice();
      if(order_sl==0 || compare_doubles(new_sl,order_sl,digits)==-1)
         if(compare_doubles(point_gain,threshold_pts,digits)>=0)
           {
            result=try_to_modify_order(ticket,NormalizeDouble(new_sl,digits),retries); 
            Print("previous sl: ",DoubleToStr(order_sl,digits),", new breakeven sl: ",DoubleToStr(new_sl,digits));         
           }
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void breakeven_check_all_orders(double threshold_percent,double plus_percent,int magic) // a -1 magic number means the there is no magic number in this order or EA
  {
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS))
         if(magic==-1 || magic==OrderMagicNumber())
           {
             breakeven_check_order(OrderTicket(),threshold_percent,plus_percent);
           }   
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
int count_similar_orders(ENUM_DIRECTIONAL_MODE mode)
  {
    int count=0;
    string this_instrument=OrderSymbol();
    string this_first_ccy=StringSubstr(this_instrument,0,3);
    string this_second_ccy=StringSubstr(this_instrument,3,3);
   
    for(int i=OrdersTotal()-1;i>=0;i--) // You have to start iterating from the lower part (or 0) of the order array because the newest trades get sent to the start. 
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
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
void cleanup_risky_pending_orders() // deletes pending orders of the entire account (no matter which EA/magic number) where the single currency of the market order would be the same direction of the single currency in the pending order
  { 
    static int last_trades_count=0;
    int trades_count=count_orders(ORDER_SET_MARKET,-1,MODE_TRADES,OrdersTotal()-1);
    
    if(last_trades_count<trades_count) // true if a limit order gets triggered and becomes a market order
      {
        if(OrderSelect(last_market_trade_ticket(),SELECT_BY_TICKET)==false) return;
        int market_trades_direction=OrderType(); // i already know it is a market order ticket because the function last_market_trade_ticket only returns market order tickets
        string market_trades_symbol=OrderSymbol();
        string market_trades_1st_ccy=StringSubstr(market_trades_symbol,0,3); // this only works if the first 3 characters of the symbol is a currency
        string market_trades_2nd_ccy=StringSubstr(market_trades_symbol,3,3); // this only works if the next 3 characters of the symbol is a currency
        
        for(int i=OrdersTotal()-1;i>=0;i--)
          {
            if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
              {
                int pending_orders_direction=OrderType();
                if(pending_orders_direction<=1) // if it is a market order or if the stoploss is at breakeven
                  break;
                else
                  {
                    string pending_orders_symbol=OrderSymbol();
                    string pending_orders_1st_ccy=StringSubstr(pending_orders_symbol,0,3);
                    string pending_orders_2nd_ccy=StringSubstr(pending_orders_symbol,3,3);
                    bool delete_pending_order=false;           
                    
                    if(market_trades_direction==OP_BUY && pending_orders_direction==OP_BUYLIMIT)
                      {
                        if(market_trades_1st_ccy==pending_orders_1st_ccy) delete_pending_order=true;
                        else if(market_trades_2nd_ccy==pending_orders_2nd_ccy) delete_pending_order=true;      
                      }
                    else if(market_trades_direction==OP_SELL && pending_orders_direction==OP_SELLLIMIT)
                      {
                        if(market_trades_1st_ccy==pending_orders_1st_ccy) delete_pending_order=true;
                        else if(market_trades_2nd_ccy==pending_orders_2nd_ccy) delete_pending_order=true;       
                      }
                    else if(market_trades_direction==OP_BUY && pending_orders_direction==OP_SELLLIMIT)
                      {
                        if(market_trades_1st_ccy==pending_orders_2nd_ccy) delete_pending_order=true;
                        else if(market_trades_2nd_ccy==pending_orders_1st_ccy) delete_pending_order=true;
                      }
                    else if(market_trades_direction==OP_SELL && pending_orders_direction==OP_BUYLIMIT)
                      {
                        if(market_trades_1st_ccy==pending_orders_2nd_ccy) delete_pending_order=true;
                        else if(market_trades_2nd_ccy==pending_orders_1st_ccy) delete_pending_order=true;
                      }
                    if(delete_pending_order==true)
                      {
                        last_trades_count=trades_count;
                        try_to_exit_order(OrderTicket(),exiting_max_slippage_pips); // TODO: get rid of the requirement for the slippage parameter
                      }
                  }
              }
          }  
      }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int last_market_trade_ticket() 
{
  datetime order_time=-1;
  int count=0;
  int ticket=0;

  for(int i=OrdersTotal()-1;i>=0;i--) 
    {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) 
        {
          if(OrderType()<=1 && OrderOpenTime()>order_time) 
            {     
              order_time=OrderOpenTime();
            }
        }
    }
  for(int i=OrdersTotal()-1;i>=0;i--) 
    {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
          if(OrderType()<=1 && OrderOpenTime()==order_time) 
            {
              count++;
              ticket=OrderTicket();
            }
        }
    }
   if(count>1) Print("Warning! There are ",count," market trades that have the same time and this situation may result in a single currency in two different currency pairs being traded in the same direction."); // TODO: create an email alert
   return(ticket);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/*void cleanup_all_pending_orders(int max_ccy_directional_trades) 
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
  }*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+