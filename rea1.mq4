//+------------------------------------------------------------------+
//|                                            Relativity_EA_V01.mq4 |
//|                                                 Quant FX Capital |
//|                                   https://www.quantfxcapital.com |
//+------------------------------------------------------------------+
#property copyright "Quant FX Capital/Tom Mazurek"
#property link      "https://www.quantfxcapital.com"
#property version   "2.11"
#property strict
/* 
Remember:
-When strategy testing, make sure you have the M5, H1, and D1 data files because they are frequently referenced in the code.
-When running the EA, make sure there are at least 3 months of D1 bars for the ADR_pts_raw to be able to calculate without Erroring out
-Always use NormalizeDouble() when computing the price (or lots or ADR?) yourself. This is not necessary for internal functions like OrderOPenPrice(), OrderStopLess(),OrderClosePrice(),Bid,Ask
-You may want to pass some values by reference (which means changing the value of a variable inside of a function by calling a different function.)
-If use_fixed_ADR==false, you have to use a broker that will give you D1 data for at least around 6 months in order to calculate the Average Daily Range (ADR).
-This EA calls the OrdersHistoryTotal() function which counts the ordres of the "Account History" tab of the terminal. Set the history there to 3 days.
*/
enum ENUM_NULL_TRUE_FALSE
  {
    myNULL=-1,
    myFALSE=0,
    myTRUE=1,
  };
enum ENUM_BAR_POINTS
  {
    myOPEN,
    myCLOSE,
    myHIGH,
    myLOW
  };
enum ENUM_PRICE_OR_TIME
  {
    myPRICE,
    myTIME
  };
enum ENUM_PIVOT_PEAK
  {
    HOP_PRICE,
    HOP_TIME,
    LOP_PRICE,
    LOP_TIME
  };
enum ENUM_INSTRUMENTS
  {
    EURJPY=-1490791745,
    EURUSD=-1490779688,
    GBPJPY=-1435125332,
    GBPUSD=-1435113275,
    USDCHF=-867508323,
    USDJPY=-867500417
  };
enum ENUM_SIGNAL_SET
  {
    SIGNAL_SET_NONE=0,
    SIGNAL_SET_1=1,
    SIGNAL_SET_2=2
  };
enum ENUM_DIRECTIONAL_MODE
  {
    BUYING_MODE=0,
    SELLING_MODE=1
  };
enum ENUM_TREND
  {
    UPTREND=0,
    DOWNTREND=1
  };
enum ENUM_RANGE
  {
    HIGH_MINUS_LOW=0,
    OPEN_MINUS_CLOSE_ABSOLUTE=1
  };
enum ENUM_DIRECTION_BIAS  // since ENUM_ORDER_TYPE is not enough, this enum was created to be able to use neutral and void signals
  {
    DIRECTION_BIAS_NOT_BUY=-4,
    DIRECTION_BIAS_NOT_SELL=-3,
    DIRECTION_BIAS_IGNORE=-2, // ignore the current filter and move on to the next one
    DIRECTION_BIAS_VOID=-1, // exit all trades
    DIRECTION_BIAS_NEUTRALIZE=0, // do not buy, sell or exit any trades
    DIRECTION_BIAS_BUY=1,
    DIRECTION_BIAS_SELL=2
  };
enum ENUM_ORDER_SET
  {
    ORDER_SET_ALL=-1,
    ORDER_SET_BUY,
    ORDER_SET_SELL,
    ORDER_SET_BUY_LIMIT,
    ORDER_SET_SELL_LIMIT, 
    ORDER_SET_LONG,
    ORDER_SET_SHORT,
    ORDER_SET_LIMIT,
    ORDER_SET_MARKET,
    ORDER_SET_PENDING,
    ORDER_SET_SHORT_LONG_LIMIT_MARKET
  };
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
  input bool        option=false;
  input bool        option2=false;
  input string      version="2.11";
  input bool        broker_is_oanda=true;              // broker_is_oanda:
  input bool        use_recommended_settings=true;     // use_recommended_settings:
  int               init_result=INIT_FAILED;
  bool              ready=false, in_time_range=false;
  //bool            price_below_ma=false, price_above_ma=false;
             
// timeframe changes
  bool              is_new_M5_bar, is_new_H1_bar, is_new_custom_D1_bar,is_new_D1_bar,is_new_custom_W1_bar;
  ///*input*/ bool    wait_next_M5_on_load=true; //wait_next_M5_on_load: This setting currently affects all bars (including D1) so do not set it to true unless code changes are made. // When you load the EA, should it wait for the next bar to load before giving the EA the ability to enter a trade or calculate ADR?
  
// general settings
  /*input*/ bool    auto_adjust_broker_digits=true;    // auto_adjust_broker_digits:
  input bool        display_chart_objects=false;       // display_chart_objects:
  input bool        print_time_info=true;              // print_time_info:
  input bool        email_alerts_on=true;              // email_alerts_on:
  static int        point_multiplier;
  static int        spread_divider;
  input bool        market_exec=false;                 // market_exec: False means that it is instant execution rather than market execution. Not all brokers offer market execution. The rule of thumb is to never set it as instant execution if the broker only provides market execution.
  int               retries=3; // TODO: eventually get rid of this global variable
  static int        magic_num; // An EA can only have one magic number. Used to identify the EA that is managing the order. TODO: see if it can auto generate the magic number every time the EA is loaded on the chart.
  static bool       uptrend=false, downtrend=false;
  static datetime   uptrend_time=-1, downtrend_time=-1;
  static bool       uptrend_order_was_last=false, downtrend_order_was_last=false;
  static double     average_spread_yesterday=0;
	
	/*input*/ bool    reverse_trade_direction=false;
	//input bool      only_enter_on_new_bar=false; // Should you only enter trades when a new bar begins?
	/*input*/ bool    exit_opposite_signal=false; //false exit_opposite_signal: Should the EA exit trades when there is a signal in the opposite direction?
  bool              long_allowed=true; // Are long trades allowed? // TODO: this is never set to anything in the code
	bool              short_allowed=true; // Are short trades allowed? // TODO: this is never set to anything in the code
		
	input bool        filter_over_extended_trends=false;  // filter_over_extended_trends: // TODO: test that this filter works
	/*input*/ int     max_pending_orders_at_once=2;       // max_pending_orders_at_once:
	//input int       max_open_trades_at_once=2;          // market_trades_at_once: How many long or short market trades can be on at the same time?
	/*input*/ int     max_directional_trades_at_once=1;   // max_directional_trades_at_once: How many trades can the EA enter at the same time in the one direction on the current chart? (If 1, a long and short trade (2 trades) can be opened at the same time.)input int max_num_EAs_at_once=28; // What is the maximum number of EAs you will run on the same instance of a platform at the same time?
	extern int        max_directional_trades_in_x_hours=2;// max_directional_trades_in_x_hours: How many trades are allowed to be opened (even if they are close now) after the start of each current day?
	extern double     x_hours=6;                          // x_hours: Any whole or fraction of an hour. // FYI, this setting only takes affect when
  
  extern int        moving_avg_period=500;              // moving_avg_period:
  input double      ma_multiplier=1;                    // ma_multiplier:
  input bool        include_weaker_ma_setup=false;      // include_weaker_ma_setup:
  /*extern*/ bool   lot_size_is_ma_distance_based=false;      // lot_size_is_ma_distance_based: so far, this variable set to true has not increased the profit factor
  extern bool       takeprofit_pts_is_ma_distance_based=true;
  extern bool       active_trade_expire_is_tp_based=false;
  
// time filters - only allow EA to enter trades between a range of time in a day
  input bool        automatic_gmt_offset=true;
	int               gmt_hour_offset;                    // gmt_hour_offset: Only tested to be working with values <=0. The value of 0 refers to the time zone used by the broker (seen as 0:00 on the chart). The code will automatically adjust this offset hour value if the broker's 0:00 server time is not equal to when the time the NY session ends their trading day.
	bool              gmt_hour_offset_is_NULL=true;       // keep as true // since in MQL4 NULL==0, this variable exists because I need a way to determine if the variable has been modified yet
	input bool        gmt_offset_visible=true;            // gmt_offset_visible: By looking at it, does the algorithm need a GMT Offset.
	input int         start_time_hour=1;                  // start_time_hour: 0-23
	input int         start_time_minute=0;                // start_time_minute: 0-59
	extern int        end_time_hour=17;                   // end_time_hour: 0-23
	extern int        end_time_minute=0;                  // end_time_minute: 0-59
	input bool        exit_trades_EOD=true;               // exit_trades_EOD
  input int         exit_time_hour=23;                  // exit_time_hour: should be before the trading range start_time and after trading range end_time
  input int         exit_time_minute=45;                // exit_time_minute: 0-59
	
	input bool        trade_friday=true;                  // trade_friday:
	extern int        fri_end_time_hour=17;               // fri_end_time_hour: 0-23
	extern int        fri_end_time_minute=0;              // fri_end_time_minute: 0-59
  input int         fri_exit_time_hour=22;              // fri_exit_time_hour
  input int         fri_exit_time_minute=45;            // fri_exit_time_min
  
// enter_order
  /*input*/ ENUM_SIGNAL_SET SIGNAL_SET=SIGNAL_SET_1; //SIGNAL_SET: Which signal set would you like to test? (the details of each signal set are found in the signal_entry function)
  // TODO: make sure you have coded for the scenerios when each of these is set to 0
	extern double     retracement_percent=.25;            // retracement_percent: Must be positive.
	input double      pullback_percent=0;                 // pullback_percent:  Must be positive. If you want a buy or sell limit order, it must be positive.
	extern double     takeprofit_percent=.4;              // takeprofit_percent: Must be a positive number. (What % of ADR should you tarket?)
  input double      stoploss_percent=1.0;               // stoploss_percent: Must be a positive number.
  input bool        prevent_ultrawide_stoploss=false;   // prevent_ultrawide_stoploss:
	input double      max_spread_percent=0;               // max_spread_percent: .05 Must be positive. What percent of ADR should the spread be less than? (Only for immediate orders and not pending.)
	//input bool      based_on_raw_ADR=true;              // true based_on_raw_ADR:true Should the max_spread_percent be calculated from the raw ADR?

// virtual stoploss variables
	int               virtual_sl=0; // 0 TODO: Change to a percent of ADR
	int               virtual_tp=0; // 0 TODO: Change to a percent of ADR
	
// breakeven variables
	input double      breakeven_threshold_percent=0;      // breakeven_threshold_percent: % of takeprofit before setting the stop to breakeven.
	input double      breakeven_plus_percent=0;           // breakeven_plus_percent: % of takeprofit above breakeven. Allows you to move the stoploss +/- from the entry price where 0 is breakeven, <0 loss zone, and >0 profit zone
  input double      negative_threshold_multiplier=0;    // negative_threshold_multiplier:
  
// trailing stop variables
	input double      trail_threshold_percent=0;          // trail_threshold_percent: % of takeprofit before activating the trailing stop.
	input double      trail_step_percent=0;               // trail_step_percent: The % of takeprofit to set the minimum difference between the proposed new value of the stoploss to the current stoploss price
	//input bool      same_stoploss_distance=true;        // false same_stoploss_distance: Use the same stoploss pips that the trade already had? If false, use the ADR as the stoploss.
	/*input*/ int     entering_max_slippage_pips=5;       // entering_max_slippage_pips: Must be in whole number. // TODO: For 3 and 5 digit brokers, is 50 equivalent to 5 pips?
//input int         unfavorable_slippage=5;

// exit or do not take orders based on time
	/*input*/ int     exiting_max_slippage_pips=50;       // exiting_max_slippage_pips: Must be in whole number. // TODO: For 3 and 5 digit brokers, is 50 equivalent to 5 pips?
	extern double     active_trade_expire=1;            // active_trade_expire: Any hours or fractions of hour(s). How many hours can a trade be on that hasn't hit stoploss or takeprofit?
  static double     active_trade_expire_stored=active_trade_expire;
	input double      pending_order_expire=0;             // pending_order_expire: Any hours or fractions of hour(s). In how many hours do you want your pending orders to expire?
	extern double     retracement_virtual_expire=.5;      // retracement_virtual_expire: Any hours or fractions of hour(s). In how many hours after the high/low do you want the potential retracement trades to expire?
	extern double     trigger_to_peak_max=0;              // trigger_to_peak_max:
	int               pending_orders_open;
  
// calculate_lots/mm variables
	ENUM_MM           money_management=MM_RISK_PERCENT_PER_ADR;
	input bool        compound_balance=false;
	extern double     risk_percent_per_range=0.03;        // risk_percent_per_range: percent risked when using the MM_RISK_PER_ADR_PERCENT money management calculations. Any amount of digits after the decimal point. Note: This is not the percent of your balance you will be risking.
	double            mm1_risk_percent=0.02;              // mm1_risk_percent: percent risked when using the MM_RISK_PERCENT money management calculations
   // these variables will not be used with the MM_RISK_PERCENT money management strategy
	double            lot_size=0.0;
	/*input*/ int     increase_lots_after_x_losses=0;
	/*input*/ double  increase_lots_by_percent=0;
	/*input*/ bool    reduce_risk_for_weaker_setups=true;
	input int         max_risky_trades=2;
	 
// Market Trends
  input bool        include_previous_day=true;
  input bool        include_last_week=false;            // include_last_week: Should the EA take Friday's moves into account when starting to determine length of the current move? FYI, when include_previous_day==false, this setting has no affect.
  extern double     H1s_to_roll=.5;                     // H1s_to_roll: Only divisible by .5 // How many hours should you roll to determine a short term market trend?
  input double      max_weekend_gap_percent=.15;        // max_weekend_gap_percent: What is the maximum weekend gap (as a percent of raw ADR) for H1s_to_roll to not take the previous week into account?
  extern double     too_big_move_percent=2.5;           // too_big_move_percent: 1.7
  extern double     range_overblown_multiplier=2;       // range_overblown_multiplier:
  input int         over_extended_x_days=0;             // over_extended_x_days: 
  extern int        past_x_days_same_trend=1;           // past_x_days_same_trend: 
  input double      move_too_big_multiplier=6;          // move_too_big_multiplier:
  extern bool       use_fixed_ADR=true;                 // use_fixed_ADR:
  extern double     fixed_ADR_pips=30;                  // fixed_ADR_pips:
  extern int        ma_range_pts=0;                     // ma_range_pts:
  static double     HOP_price;
  static datetime   HOP_time;
  static double     LOP_price;
  static datetime   LOP_time;
  static int        moves_start_bar;                    // the periods_pivot_price function uses this
  static datetime   hours_open_time=-1;  
  static datetime   days_open_time=-1;                  // keep it at -1
  static datetime   weeks_open_time=-1;                 // keep it at -1
  static datetime   last_weeks_end_time=-1;

// Average Daily Range
  static double     ADR_pts;
  static double     ADR_pts_raw;
  extern int        num_ADR_months=1;                   // num_ADR_months: How many months to use to calculate the average ADR?
  input double      change_ADR_percent=0;               // change_ADR_percent: this can be a 0, negative, or positive decimal or whole number. 
// TODO: make sure you have coded for the scenerios when each of these is set to 0
  input double      above_ADR_outlier_percent=1.5;      // above_ADR_outlier_percent: 1.5 Can be any decimal with two numbers after the decimal point or a whole number. // How much should the ADR be surpassed in a day for it to be neglected from the average calculation?
  input double      below_ADR_outlier_percent=.5;       // below_ADR_outlier_percent: .5 Can be any decimal with two numbers after the decimal point or a whole number. // How much should the ADR be under in a day for it to be neglected from the average calculation?
  
  double pivot_peak[20][5]={}; // The columns are: instrument_id,HOP_price,HOP_time,LOP_price,LOP_time
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
// Runs once when the EA is turned on
int OnInit()
  {
    init_result=INIT_FAILED;
    init_result=on_initialization(SIGNAL_SET,Symbol());
    //print_info(Symbol());
    if(init_result==INIT_FAILED) 
      {
        print_and_email("Error","INIT_FAILED="+IntegerToString(INIT_FAILED)+" and the OnInit() result is: "+IntegerToString(init_result)+" (anything other than 0 means it failed)");
        platform_alert("Error","INIT_FAILED="+IntegerToString(INIT_FAILED)+" and the OnInit() result is: "+IntegerToString(init_result)+" (anything other than 0 means it failed)");
        Sleep(1000);
        ExpertRemove();
      }
    return init_result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool print_broker_info(string instrument)
  {
    /*
    Print("Symbol=",Symbol()); 
    Print("Low day price=",MarketInfo(Symbol(),MODE_LOW)); 
    Print("High day price=",MarketInfo(Symbol(),MODE_HIGH));  
    Print("Point size in the quote currency=",MarketInfo(Symbol(),MODE_POINT)); 
    Print("Digits after decimal point=",MarketInfo(Symbol(),MODE_DIGITS)); 
    Print("Spread value in points=",MarketInfo(Symbol(),MODE_SPREAD)); 
    Print("Stop level in points=",MarketInfo(Symbol(),MODE_STOPLEVEL)); 
    Print("Lot size in the base currency=",MarketInfo(Symbol(),MODE_LOTSIZE)); 
    Print("Tick value in the deposit currency=",MarketInfo(Symbol(),MODE_TICKVALUE)); 
    Print("Tick size in points=",MarketInfo(Symbol(),MODE_TICKSIZE));  
    Print("Trade is allowed for the symbol=",MarketInfo(Symbol(),MODE_TRADEALLOWED)); 
    Print("Minimum permitted amount of a lot=",MarketInfo(Symbol(),MODE_MINLOT)); 
    Print("Step for changing lots=",MarketInfo(Symbol(),MODE_LOTSTEP)); 
    Print("Maximum permitted amount of a lot=",MarketInfo(Symbol(),MODE_MAXLOT)); 
    Print("Swap calculation method=",MarketInfo(Symbol(),MODE_SWAPTYPE)); 
    Print("Profit calculation mode=",MarketInfo(Symbol(),MODE_PROFITCALCMODE)); 
    Print("Margin calculation mode=",MarketInfo(Symbol(),MODE_MARGINCALCMODE)); 
    Print("Initial margin requirements for 1 lot=",MarketInfo(Symbol(),MODE_MARGININIT)); 
    Print("Margin to maintain open orders calculated for 1 lot=",MarketInfo(Symbol(),MODE_MARGINMAINTENANCE)); 
    Print("Hedged margin calculated for 1 lot=",MarketInfo(Symbol(),MODE_MARGINHEDGED)); 
    Print("Free margin required to open 1 lot for buying=",MarketInfo(Symbol(),MODE_MARGINREQUIRED)); 
    Print("Order freeze level in points=",MarketInfo(Symbol(),MODE_FREEZELEVEL)); 
    */
    string   current_bar_open_time=TimeToString(iTime(instrument,PERIOD_M5,0));        
    datetime current_time=(datetime)MarketInfo(instrument,MODE_TIME);
    bool     market_open_today=is_market_open_today(instrument,current_time);
    string   instrument_int=IntegerToString(get_string_integer(StringSubstr(instrument,0,6)));
    string   expert_name=WindowExpertName();
    string   tick_value=DoubleToString(MarketInfo(instrument,MODE_TICKVALUE));
    double   point=MarketInfo(instrument,MODE_POINT);
    double   spread=MarketInfo(instrument,MODE_SPREAD);
    string   bid_price=DoubleToString(MarketInfo(instrument,MODE_BID));
    double   min_distance_pips=MarketInfo(instrument,MODE_STOPLEVEL);
    string   min_lot=DoubleToString(MarketInfo(instrument,MODE_MINLOT));
    string   max_lot=DoubleToString(MarketInfo(instrument,MODE_MAXLOT));
    string   lot_digits=IntegerToString((int) -MathLog10(MarketInfo(instrument,MODE_LOTSTEP)));
    string   lot_step=IntegerToString((int)(MarketInfo(instrument,MODE_LOTSTEP)));
    int      digits=(int)MarketInfo(instrument,MODE_DIGITS);
    bool     trade_allowed=(int)MarketInfo(instrument,MODE_TRADEALLOWED);
    string   one_lot_initial_margin=DoubleToString(MarketInfo(instrument,MODE_MARGININIT));
    string   margin_to_maintain_open_orders=DoubleToString(MarketInfo(instrument,MODE_MARGINMAINTENANCE));
    string   hedged_margin=DoubleToString(MarketInfo(instrument,MODE_MARGINHEDGED));
    string   free_margin_required=DoubleToString(MarketInfo(instrument,MODE_MARGINREQUIRED));
    string   freeze_level_pts=DoubleToString(MarketInfo(instrument,MODE_FREEZELEVEL));
    string   current_chart=Symbol();
    
    Print("Account company: ",AccountCompany());
    Print("Account name: ", AccountName());
    Print("Account number: ", IntegerToString(AccountNumber()));
    Print("Account Server Name: ", AccountServer());
    Print("current time: ",TimeToString(current_time));
    Print("current bar open time: ",current_bar_open_time);
    Print("market_open_today: ",market_open_today);
    Print(StringSubstr(instrument,0,6),"'s string integer: ",instrument_int);
    Print("expert_name: ",expert_name);
    Print("trade_allowed: ",trade_allowed);
    Print("one_lot_initial_margin: ",one_lot_initial_margin);
    Print("margin_to_maintain_open_orders for 1 lot: ",margin_to_maintain_open_orders);
    Print("hedged_margin: ",hedged_margin);
    Print("free_margin_required to open 1 lot: ",free_margin_required);
    Print("freeze_level_pts: ",freeze_level_pts);
    Print("tick_value: ",tick_value);
    Print("Point: ",DoubleToStr(point));
    Print("spread before the function calls: ",DoubleToStr(spread));
    Print("spread before the function calls * point: ",DoubleToStr(spread*point));
    Print("spread before the function calls * point * point_multiplier: ",DoubleToStr(spread*point*point_multiplier));
    if(broker_is_oanda) Print("Oanda spread before the function calls * point * point_multiplier / spread_divider: ",DoubleToStr(spread*point*point_multiplier/spread_divider));
    Print("ADR_pts: ",DoubleToStr(ADR_pts)); 
    Print("bid_price: ",bid_price);
    Print("min_distance_pips: ",DoubleToStr(min_distance_pips));
    Print("min_distance_pips*point: ",DoubleToStr(min_distance_pips*point));
    Print("min_distance_pips*point*point_multiplier: ",NormalizeDouble(min_distance_pips*point*point_multiplier,digits));
    Print("(min_distance_pips*point*point_multiplier)*max_spread_percent: ",DoubleToStr(NormalizeDouble(min_distance_pips*point*point_multiplier*max_spread_percent,digits))); 
    Print("min_lot: ",min_lot," .01=micro lots, .1=mini lots, 1=standard lots");
    Print("max_lot: ",max_lot);
    Print("lot_digits: ",lot_digits," after the decimal point.");
    Print("lot_step: ",lot_step);    
    Print("broker digits: ",IntegerToString(digits)," after the decimal point.");
    Print("current_chart: ",current_chart);
    return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void print_and_email(string subject,string body,bool exclude_print=false)
  {
    if(exclude_print==false) Print(subject,": ",body);
    if(email_alerts_on) SendMail(subject,subject+": "+body);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void print_and_email_margin_info(string instrument,string subject)
  {

    string  stopout_level=IntegerToString(AccountStopoutLevel()),
            account_stopout_level=IntegerToString(AccountStopoutLevel()),
            account_stopout_mode=IntegerToString(AccountStopoutMode()),
            account_leverage=IntegerToString(AccountLeverage()),
            account_margin=DoubleToStr(AccountMargin()),
            account_equity=DoubleToStr(AccountEquity()),
            one_lot_initial_margin=DoubleToStr(MarketInfo(instrument,MODE_MARGININIT)),
            margin_to_maintain_open_orders=DoubleToStr(MarketInfo(instrument,MODE_MARGINMAINTENANCE)),
            hedged_margin=DoubleToStr(MarketInfo(instrument,MODE_MARGINHEDGED)),
            free_margin_required=DoubleToStr(MarketInfo(instrument,MODE_MARGINREQUIRED)),
            freeze_level_pts=DoubleToStr(MarketInfo(instrument,MODE_FREEZELEVEL));
    /*Print(subject,": stopout_level: ",stopout_level);
    Print(subject,": one_lot_initial_margin: ",one_lot_initial_margin);
    Print(subject,": margin_to_maintain_open_orders for 1 lot: ",margin_to_maintain_open_orders);
    Print(subject,": hedged_margin: ",hedged_margin);
    Print(subject,": free_margin_required to open 1 lot: ",free_margin_required);
    Print(subject,": freeze_level_pts: ",freeze_level_pts);*/
    if(email_alerts_on) 
      {
        string email_body=StringConcatenate("stopout_level: ",stopout_level,
                                            ", account_stopout_level: ",account_stopout_level,
                                            ", account_stopout_mode: ",account_stopout_mode,
                                            ", account_leverage: ",account_leverage,
                                            ", account_margin: ",account_margin,
                                            ", account_equity: ",account_equity,
                                            ", one_lot_initial_margin: ",one_lot_initial_margin,
                                            ", margin_to_maintain_open_orders for 1 lot: ",margin_to_maintain_open_orders,
                                            ", hedged_margin for 1 lot: ",hedged_margin,
                                            ", free_margin_required to open 1 lot: ",free_margin_required,
                                            ", freeze_level_pts: ",freeze_level_pts
                                           );
        SendMail(subject,subject+": "+email_body);
      }  
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void platform_alert(string subject,string body)
  {
    Alert(subject,": ",body);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int on_initialization(ENUM_SIGNAL_SET signal_set,string instrument)
  {
    /*string foldername="C:\\Users\\xmacb\\AppData\\Roaming\\MetaQuotes\\Terminal\\F2262CFAFF47C27887389DAB2852351A\\tester\\logs";
    PrintFormat("Trying to delete all files from folder %s",foldername);
    if(FolderClean(foldername,0))
       PrintFormat("Files have been successfully deleted, %d files left in folder %s");
    else
       PrintFormat("Failed to delete files from folder %s. Error code %d",foldername,GetLastError());*/
       
    bool ran=false;
    ran=ran(set_point_multiplier(instrument));
    Print(ran," 1");
    ran=ran(set_spread_divider());
    Print(ran," 2");
    magic_num=set_magic_num(WindowExpertName(),signal_set);
    // assign values to HOP_price, LOP_price, HOP_time, LOP_time

    /*int eurjpy=get_string_integer("EURJPY");
    int eurusd=get_string_integer("EURUSD");
    int usdjpy=get_string_integer("USDJPY");
    Print(eurjpy);
    Print(eurusd);
    Print(usdjpy);*/

    // TODO: before following through on this, make sure that the get_string_integer function actually creates a unique ID for all the ccy pairs you plan to trade.
    // Each cell in the two dimensional array (table) has to be assigned individually and cannot be done in bulk due to the limitation of the programming language.
    pivot_peak[0][0]=EURJPY; pivot_peak[0][1]=HOP_price; pivot_peak[0][2]=HOP_time; pivot_peak[0][3]=LOP_price; pivot_peak[0][4]=LOP_time;
    pivot_peak[1][0]=EURUSD; pivot_peak[0][1]=HOP_price; pivot_peak[0][2]=HOP_time; pivot_peak[0][3]=LOP_price; pivot_peak[0][4]=LOP_time;
    pivot_peak[2][0]=USDJPY; pivot_peak[0][1]=HOP_price; pivot_peak[0][2]=HOP_time; pivot_peak[0][3]=LOP_price; pivot_peak[0][4]=LOP_time;
      
    ran=ran(ran,set_recommended_input_parameters(instrument,use_recommended_settings));
    Print(ran," 3");
    //EventSetTimer(60);
    ran=ran(ran,set_gmt_offset(instrument,TimeCurrent(),610)); // this should run before set_moves_start_bar (which takes gmt_hour_offset as a parameter) as well all the other "new bar" functions
    Print(ran," 4");
    ran=ran(ran,set_moves_start_bar(instrument,H1s_to_roll,gmt_hour_offset,max_weekend_gap_percent,include_last_week));
    Print(ran," 5");
    reset_pivot_peak(instrument); // the set_moves_start_bar function should run before this function (only on initialization)
    is_new_M5_bar(instrument,true);
    ADR_pts_raw=get_ADR_pts_raw(instrument,H1s_to_roll,below_ADR_outlier_percent,above_ADR_outlier_percent,num_ADR_months);
    set_changed_ADR_pts(H1s_to_roll,below_ADR_outlier_percent,above_ADR_outlier_percent,change_ADR_percent,instrument,ADR_pts_raw); // this should be after the recommended settings are set because, if requested, a change should be done after
    is_new_H1_bar(instrument,false);
    set_custom_D1_open_time(instrument,0);
    is_new_custom_D1_bar(instrument,TimeCurrent()); // This is here so I do not have to rely on the is_new_H1_bar function to return true, in order to populate the variables which are populated within the function. This has to be run after the get_custom_D1_open_time function
    set_custom_W1_times(instrument,include_last_week,H1s_to_roll,gmt_hour_offset); // this will get a value for the weeks_open_time global variable
    is_new_custom_W1_bar(instrument,false);

    print_broker_info(instrument); // set_point_multiplier and set_spread_divider has to run before this function is called
    Print(instrument,"'s Magic Number: ",IntegerToString(magic_num));

    // TODO: consider a check of if the broker has Sunday's as a server time, and, if not, block all the code you wrote to count Sunday's from running

    string result_message;
    int result;
    if(input_parameters_valid()==false)
      {
        result_message="The initialization of the EA failed. Make sure that the trade exit_time_hour and exit_time_minute combination does not fall within the trading range start and end times or else there will be trouble!";
        result=INIT_FAILED;
      }
    else if(magic_num<=0)
      {
        result_message="The initialization of the EA failed. The magic number ("+IntegerToString(magic_num)+") is not a valid magic number for the Expert Advisor (EA). Without one, the EA will not run correctly. Get a MQL4 programmer check the code to find out why.";
        result=INIT_FAILED;
      }
    else if(ran==false)
      {
        result_message="The initialization of the EA failed. Not every function ran successfully.";
        result=INIT_FAILED;
      }
    else
      {
        Print("The initialization of the EA finished successfully.");
        result=INIT_SUCCEEDED;
      }
    if(result==INIT_FAILED) 
      {
        print_and_email("Error",result_message);
        platform_alert("Error",result_message);
      }
    return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool input_parameters_valid() // TODO: add more
  {
    int range_start_time=(start_time_hour*3600)+(start_time_minute*60);
    int range_end_time=(end_time_hour*3600)+(end_time_minute*60);
    int exit_time=(exit_time_hour*3600)+(exit_time_minute*60);
    if(exit_time>range_start_time && exit_time>=range_end_time) 
      return true;
    else 
      return false;
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
          text="The account was changed"; break;
        case REASON_CHARTCHANGE:
          text="The symbol or timeframe was changed"; break;
        case REASON_CHARTCLOSE:
          text="The chart was closed"; break;
        case REASON_PARAMETERS:
          text="The input-parameter was changed"; break;
        case REASON_RECOMPILE: 
          text="The program "+__FILE__+" was recompiled"; break;
        case REASON_REMOVE:
          text="Program "+__FILE__+" was removed from chart"; break;
        case REASON_TEMPLATE:
          text="A new template was applied to chart"; break;
        default:
          text="A different reason";
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
//| Expert tick functions                                            |
//+------------------------------------------------------------------+
void OnTimer()
  {
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
    string    instrument=Symbol();
    int       digits=(int)MarketInfo(instrument,MODE_DIGITS); // TODO: think about putting digits in the parameter of every function that needs the digits variable. Currently this retrieval of digits is only getting passed to the relativity_ea_ran function
    datetime  current_time=(datetime)MarketInfo(instrument,MODE_TIME);
    double    current_bid=MarketInfo(instrument,MODE_BID);
    int       exit_signal=DIRECTION_BIAS_NEUTRALIZE, exit_signal_2=DIRECTION_BIAS_NEUTRALIZE; // 0
    int       _exiting_max_slippage=exiting_max_slippage_pips;
    bool      relativity_ea_2_on=false;
    bool      ea_ran=false;
    if(init_result==INIT_SUCCEEDED)
      {
        static bool safe_to_trade=true;
        static bool trading_paused=false;
        safe_to_trade=risk_percent_per_range>0;
        is_new_M5_bar=is_new_M5_bar(instrument,true);
        if(pullback_percent>0) 
          {
            // do maintenance of pending orders
            cleanup_risky_pending_orders(instrument);
            pending_orders_open=count_orders(ORDER_SET_PENDING,magic_num,MODE_TRADES,OrdersTotal()-1); // count all open order (but only for the specific magic number)
            if(pending_orders_open>max_pending_orders_at_once) 
              {
                int ticket=last_order_ticket(ORDER_SET_PENDING,false);
                if(ticket>0) try_to_exit_order(ticket,exiting_max_slippage_pips);
              }
          }
        if(is_new_M5_bar)
          {
            is_new_H1_bar=is_new_H1_bar(instrument,true);
            if(is_new_H1_bar) 
              {
                //Print("hourly gmt: ",gmt_hour_offset);
                set_custom_D1_open_time(instrument,0); // Since the gmt_hour_offset was just set, that means that the custom D1 open time can also be different and, also, the next line (is_new_custom_D1_bar) uses the days_open_time variable. So this function needs to be here to assign the updated value to the variable.             
                is_new_custom_D1_bar=is_new_custom_D1_bar(instrument,current_time); // set_gmt_offset needs to be run before is_new_custom_D1_bar because is_new_custom_D1_bar uses the gmt_offset_hour variable
                // set_gmt_offset has to run here because the broker's server time can change very frequently, so this function needs to get called frequently
                // also because set_gmt_offset can only be run after is_new_D1_bar and is_new_custom_D1_bar is run
                safe_to_trade=boolean_compare(safe_to_trade,set_gmt_offset(instrument,current_time,750)); 
                if(gmt_offset_visible==false && (gmt_hour_offset!=0 /*|| gmt_hour_offset_is_NULL*/)) 
                  {
                    print_and_email("Error","THE EA WILL FOR "+instrument+" WILL BE TERMINATED BECAUSE THE gmt_hour_offset IS 0 OR NULL");
                    platform_alert("Error","THE EA WILL FOR "+instrument+" WILL BE TERMINATED BECAUSE THE gmt_hour_offset IS 0 OR NULL");
                    Sleep(1000);
                    ExpertRemove();
                  }
                /*if(is_new_D1_bar)
                  {
                    double open_price=get_previous_days_bar_info(instrument,OPEN,PRICE);
                    datetime open_time=(datetime)get_previous_days_bar_info(instrument,OPEN,TIME);
                    double close_price=get_previous_days_bar_info(instrument,CLOSE,PRICE);
                    datetime close_time=(datetime)get_previous_days_bar_info(instrument,CLOSE,TIME);
                    double high_price=get_previous_days_bar_info(instrument,HIGH,PRICE);
                    datetime high_time=(datetime)get_previous_days_bar_info(instrument,HIGH,TIME);
                    double low_price=get_previous_days_bar_info(instrument,LOW,PRICE);
                    datetime low_time=(datetime)get_previous_days_bar_info(instrument,LOW,TIME);
                    Print("open_price: ",DoubleToStr(open_price));
                    Print("open_time: ",TimeToStr(open_time));
                    Print("close_price: ",DoubleToStr(close_price));
                    Print("close_time: ",TimeToStr(close_time));
                    Print("high_price: ",DoubleToStr(high_price));
                    Print("high_time: ",TimeToStr(high_time));
                    Print("low_price: ",DoubleToStr(low_price));
                    Print("low_time: ",TimeToStr(low_time));
                  }*/
                //if(trading_paused) Print("Trading is still paused.");
                if(is_new_custom_D1_bar)  // this must run before relativity_ea_ran function is run
                  {
                    is_new_custom_W1_bar=is_new_custom_W1_bar(instrument,false);
                    safe_to_trade=boolean_compare(safe_to_trade,is_day_to_trade());
                    ready=false; // Set ready to false at the beginning of every day. The code will soon check if it is ready once again. The relativity_ea_ran function has to be called soon.
                    //set_custom_W1_times(instrument,include_last_week,H1s_to_roll,gmt_hour_offset);
                    if(is_new_custom_W1_bar)
                      {
                        int orders_for_week=count_orders(ORDER_SET_ALL,magic_num,MODE_HISTORY,OrdersHistoryTotal(),604800,current_time);
                        print_and_email("Info","Total "+instrument+" orders for the week:------------------- "+IntegerToString(orders_for_week));
                        print_and_email("Info","Account Balance: "+DoubleToString(AccountBalance()),true);
                        safe_to_trade=boolean_compare(safe_to_trade,set_gmt_offset(instrument,current_time,775)); // since it is a new week, it will trigger the gmt_offset_required to re-evaluate (which I want to happen at the beginning of each week
                      }
                    if(trading_paused) 
                      {
                        trading_paused=false;
                        print_and_email("Important Info","Trading for "+instrument+" should have unpaused and resumed.");
                      }
                  }
                /*if(is_new_D1_bar)
                  {
                    if(safe_to_trade) safe_to_trade=boolean_compare(safe_to_trade,is_previous_D1_bar_correct_length(instrument,current_time));
                  }*/
              }
          }
        if(safe_to_trade && trading_paused==false) 
            ea_ran=main_script_ran(instrument,digits,magic_num,current_time,exit_signal,exit_signal_2,_exiting_max_slippage,current_bid); // TODO: test by typing "USDJPYpro" as a replacement to instrument
        else if(is_new_D1_bar || is_new_custom_D1_bar) 
          {
            trading_paused=true;
            //gmt_hour_offset=NULL; // setting gmt_hour_offset to NULL will allow the set_gmt_offset function to try to set it the next time it is called
            print_and_email("Warning & Important Info","IT IS NOT SAFE TO TRADE TODAY. TRADING WILL BE PAUSED AND RE-EVALUATED THE NEXT TIME GMT IS 0:00.");
          }  
        if(is_new_D1_bar || is_new_custom_D1_bar) safe_to_trade=true; // by setting safe_to_trade=true, you are letting it be re-evaluated on the first tick for each day's broker and custom bar
        // Since the functions that return the true/false of whether it is a new bar do not run on every tick, the global variables need to be set to false after all the previous code gets run. Otherwise, many of them will stay true much too frequently.
        if(is_new_M5_bar==true)
          {
            is_new_M5_bar=false;
            is_new_H1_bar=false;
            is_new_D1_bar=false;
            is_new_custom_D1_bar=false;
            is_new_custom_W1_bar=false;
          }
      }
    else 
      {
        print_and_email("Error","The OnInit function failed to complete and, therefore, the algorithm cannot proceed running.");
        platform_alert("Error","The OnInit function failed to complete and, therefore, the algorithm cannot proceed running.");
        Sleep(1000);
        ExpertRemove();
      }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_previous_D1_bar_correct_length(string instrument,datetime current_time)
  {
    int current_day=TimeDayOfWeek(current_time);
    if(current_day<=1)
      {
        return true;
      }
    else
      {
        datetime current_day_time=iTime(instrument,PERIOD_D1,0);
        datetime previous_day_time=iTime(instrument,PERIOD_D1,1);
        int previous_day=TimeDayOfWeek(previous_day_time);
        //Print("day of week: ",TimeDayOfWeek(current_day)," current_day: ",TimeToStr(current_day_time));
        //Print("day of week: ",TimeDayOfWeek(previous_day)," previous_day: ",TimeToStr(previous_day_time));
        double hours_yesterday=double((current_day_time-previous_day_time)/3600); // keep it as a double not an int
        if(MathMod(hours_yesterday,24)!=0 || hours_yesterday>48) print_and_email("Warning","hours_yesterday: "+DoubleToString(hours_yesterday)); // the reason I am using MathMod is because sometimes brokers don't provide data or trading on holiday so, if the calculation is two days (24+24)=48 then that is okay
        if(current_day-previous_day==1 && hours_yesterday==24) return true;
      }
    print_and_email("Warning","TRADING WILL NOT HAPPEN TO TODAY BECAUSE THE PREVIOUS D1 BAR WAS NOT 24 HOURS LONG");
    return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double get_pivot_peak_info(ENUM_PIVOT_PEAK en,string instrument) // TODO: this function is not yet called anywhere
  {
    int instrument_id=get_string_integer(StringSubstr(instrument,0,6));
    int row=-1;
    int column;
    int i=0;
    switch(en)
      {
        case HOP_PRICE:
          column=1; break;
        case HOP_TIME:
          column=2; break;
        case LOP_PRICE:
          column=3; break;
        case LOP_TIME:
          column=4; break;
      }
    while(row==-1 && i<50) // TODO: you might want to use ArraySize() instead of 50
      {
        double j=pivot_peak[i][0];
        if(j==instrument_id)
          {
            row=i;
          }
        i++;
      }
    if(row!=-1) return pivot_peak[row][column];
    else return -1;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/*bool is_HOP_HOD(string instrument)
  {
    if(HOP_price==iHigh(instrument,PERIOD_D1,0)) return true;
    else return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_LOP_LOD(string instrument)
  {
    if(HOP_price==iLow(instrument,PERIOD_D1,0)) return true;
    else return false;
  }*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool a_trade_closed_since_last_checked(int magic)
  {
    static int last_trade_count=-1;
    if(last_trade_count==-1) last_trade_count=count_orders(ORDER_SET_MARKET,magic,MODE_TRADES,OrdersTotal()-1);
    int current_trade_count=count_orders(ORDER_SET_MARKET,magic,MODE_TRADES,OrdersTotal()-1);
    //Print("last_trades_count==",last_trade_count);
    //Print("current_trade_count==",current_trade_count);
    if(current_trade_count==last_trade_count-1) 
      {
        last_trade_count=current_trade_count;
        //Print("a_trade_closed_since_last_checked=true");
        return true;
      }  
    else 
      {
        last_trade_count=current_trade_count;
        return false;
      }   
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool main_script_ran(string instrument,int digits,int magic,datetime current_time,int exit_signal,int exit_signal_2,int _exiting_max_slippage,double current_bid)
  {
    string  current_chart=Symbol();
    bool    current_chart_matches=(current_chart==instrument);
    bool    _display_chart_objects=(display_chart_objects && current_chart_matches);
    if(_display_chart_objects)
      {
        if(ObjectFind(current_chart+"_LOP_price")<0)
          {
            ObjectCreate(current_chart+"_LOP_price",OBJ_HLINE,0,LOP_time,LOP_price);
            ObjectSet(current_chart+"_LOP_price",OBJPROP_COLOR,clrBlue);
            ObjectSet(current_chart+"_LOP_price",OBJPROP_STYLE,STYLE_DOT);
          }
        if(ObjectFind(current_chart+"_HOP_price")<0)
          {
            ObjectCreate(current_chart+"_HOP_price",OBJ_HLINE,0,HOP_time,HOP_price);
            ObjectSet(current_chart+"_HOP_price",OBJPROP_COLOR,clrBlue);
            ObjectSet(current_chart+"_HOP_price",OBJPROP_STYLE,STYLE_DOT);
          }
        string name=current_chart+"_last_order_direction";
        if(ObjectFind(name)<0)
          {
            ObjectCreate(name,OBJ_LABEL,0,0,0);
            ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
            if(uptrend_order_was_last) ObjectSetString(0,name,OBJPROP_TEXT,"uptrend order was last");
            else if(downtrend_order_was_last) ObjectSetString(0,name,OBJPROP_TEXT,"downtrend order was last");
            else ObjectSetString(0,name,OBJPROP_TEXT,"? order was last");      
          }
        ObjectSet(current_chart+"_LOP_price",OBJPROP_PRICE1,LOP_price);
        ObjectSet(current_chart+"_LOP_price",OBJPROP_TIME1,LOP_time);
        ObjectSet(current_chart+"_HOP_price",OBJPROP_PRICE1,HOP_price); 
        ObjectSet(current_chart+"_HOP_price",OBJPROP_TIME1,HOP_time);    
      }
    /*exit_signal=signal_exit(instrument,SIGNAL_SET); // The exit signal should be made the priority and doesn't require in_time_range or adr_generated to be true
    if(exit_signal==DIRECTION_BIAS_VOID)       exit_all_trades_set(_exiting_max_slippage,ORDER_SET_ALL,magic); // close all pending and orders for the specific EA's orders. Don't do validation to see if there is an magic_num because the EA should try to exit even if for some reason there is none.
    else if(exit_signal==DIRECTION_BIAS_BUY)   exit_all_trades_set(_exiting_max_slippage,ORDER_SET_SHORT,magic);
    else if(exit_signal==DIRECTION_BIAS_SELL)  exit_all_trades_set(_exiting_max_slippage,ORDER_SET_LONG,magic);*/
    if(breakeven_threshold_percent>0) breakeven_check_all_orders(breakeven_threshold_percent,breakeven_plus_percent,magic);
    if(trail_threshold_percent>0) trailingstop_check_all_orders(trail_threshold_percent,trail_step_percent,magic);
    //   virtualstop_check(virtual_sl,virtual_tp); 
    if(is_new_M5_bar) 
      {
        bool a_trade_closed=a_trade_closed_since_last_checked(magic);
        if(a_trade_closed && active_trade_expire_is_tp_based) 
          {
            Print("active_trade_expire was ",DoubleToString(active_trade_expire,2)," but has now been changed to ",DoubleToString(active_trade_expire_stored,2)," of an hour.");
            active_trade_expire=active_trade_expire_stored;
          }
        if(expired_pivot_level(current_time) || 
           expired_peak_level(current_time) || 
           a_trade_closed || 
           is_range_overblown(range_overblown_multiplier))
          {
            // reset the LOP_price, HOP_price, and trends because the signal is no longer valid
            reset_pivot_peak(instrument);
          }
        if(active_trade_expire>0) exit_all_trades_set(_exiting_max_slippage,ORDER_SET_MARKET,magic,int(active_trade_expire*3600),current_time); // This runs every 5 minutes (whether the time is in_time_range or not). It only exit trades that have been on for too long and haven't hit stoploss or takeprofit.
        in_time_range=in_time_range(current_time,start_time_hour,start_time_minute,end_time_hour,end_time_minute,fri_end_time_hour,fri_end_time_minute,gmt_hour_offset,current_bid); // only check if it is in the time range once the EA is loaded and, then, afterward at the beginning of every M5 bar  
        if(in_time_range==true && ready==false && average_spread_yesterday!=-1) 
          {
            set_gmt_offset(instrument,current_time,1140);
            ADR_pts_raw=get_ADR_pts_raw(instrument,H1s_to_roll,below_ADR_outlier_percent,above_ADR_outlier_percent,num_ADR_months);
            set_changed_ADR_pts(H1s_to_roll,below_ADR_outlier_percent,above_ADR_outlier_percent,change_ADR_percent,instrument,ADR_pts_raw);
            average_spread_yesterday=calculate_avg_spread_yesterday(instrument);
            bool is_acceptable_spread=true; // TODO: delete this line after finishing the average_spread_yesterday function
            if(ADR_pts>0 && ADR_pts_raw>0 && magic>0 && is_acceptable_spread==true && days_open_time>0 && gmt_hour_offset_is_NULL==false) // days_open_time is required to have been generated in order to prevent duplicate trades or allow trades to happen
              {
                // reset all trend analysis and uptrend/downtrend alternating to start fresh for the day
                uptrend_order_was_last=false;
                downtrend_order_was_last=false;
                ObjectSetString(0,current_chart+"_last_order_direction",OBJPROP_TEXT,"? order was last");
                ObjectSet(current_chart+"_HOP",OBJPROP_WIDTH,1);
                ObjectSet(current_chart+"_LOP",OBJPROP_WIDTH,1);
                ready=true; // the ADR and average spread yesterday that has just been calculated won't generate again until after the cycle of not being in the time range completes
                //Print("INFO: THE ALGORITHM IS READY");
              }
            else
              {
                static datetime last_sent=-1;
                datetime today=round_down_to_days(current_time);
                if(last_sent==-1 || (last_sent!=today && (is_new_D1_bar || is_new_custom_D1_bar))) 
                  {
                    string not_ready="THE EA FOR "+instrument+" IS NOT READY FOR TRADING";
                    ready=false; // never assign average_spread_yesterday to anything in this scope
                    if(ADR_pts==0 || ADR_pts==NULL)
                        print_and_email("Error",not_ready+" because ADR_pts was not generated");
                    if(ADR_pts_raw==0 || ADR_pts==NULL)
                        print_and_email("Error",not_ready+" because ADR_pts_raw was not generated");
                    if(magic<=0 || magic==NULL)
                        print_and_email("Error",not_ready+" because the magic number was not generated"); 
                    if(days_open_time<=0 || days_open_time==NULL)
                        print_and_email("Error",not_ready+" because days_open_time was not generated");
                    if(gmt_hour_offset_is_NULL)
                        print_and_email("Error",not_ready+" because gmt_hour_offset was not generated");   
                    if(is_acceptable_spread==false)
                      {
                        /*Steps that were used to calculate percent_allows_trading:
                        double max_spread=((ADR_pts)*max_spread_percent);
                        double spread_diff=average_spread_yesterday-max_spread;
                        double spread_diff_percent=spread_diff/(ADR_pts);
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
                    last_sent=round_down_to_days(current_time);
                  }
              }  
          }
        if(_display_chart_objects)
          {
            if(is_new_H1_bar)
              {
                static bool last_uptrend_order=uptrend_order_was_last;
                static bool last_downtrend_order=downtrend_order_was_last;
                if((last_uptrend_order!=uptrend_order_was_last) || (last_downtrend_order!=downtrend_order_was_last)) // if there was a change since last checked
                  {
                    ObjectDelete(current_chart+"_retrace_HOP_up");
                    ObjectDelete(current_chart+"_retrace_HOP_down");
                    ObjectDelete(current_chart+"_retrace_LOP_up");
                    ObjectDelete(current_chart+"_retrace_LOP_down");
                    last_uptrend_order=uptrend_order_was_last;
                    last_downtrend_order=downtrend_order_was_last;  
                  }
                double bid_price=current_bid;
                string dow_text=current_chart+"_day_of_week";
                if(ObjectFind(dow_text)<0)
                  {
                    ObjectCreate(dow_text,OBJ_TEXT,0,TimeCurrent(),bid_price);
                    ObjectSetText(dow_text,"0",15,NULL,clrWhite);
                  }
                ObjectSetText(dow_text,IntegerToString(DayOfWeek(),1),0);
                if(uptrend) ObjectMove(dow_text,0,TimeCurrent(),bid_price-ADR_pts/2);
                else ObjectMove(dow_text,0,TimeCurrent(),bid_price+ADR_pts/2);
              }    
          }
      }
    if(ready && in_time_range)
      {
        // start to filter and generally look for the buy or sell enter signals before specifically analyzing the buy and sell signals
        ENUM_DIRECTION_BIAS enter_signal=DIRECTION_BIAS_NEUTRALIZE; // 0
        bool reduced_risk=false;
        if(is_new_M5_bar) 
          {
            set_moves_start_bar(instrument,H1s_to_roll,gmt_hour_offset,max_weekend_gap_percent,include_last_week); // this is here so the vertical line can get moved every 5 minutes
            //Print("moves_start_bar=",moves_start_bar);
          }
        if(option)
          {
            /*enter_signal=_signal_MA_better_test(instrument,Bid);
            if(retracement_percent>0)
              {
                _signal_ADR_triggered_test(instrument);
                enter_signal=signal_bias_compare(enter_signal,signal_retracement_after_ADR_triggered(instrument));
              }
            else 
                enter_signal=signal_ADR_triggered(instrument);*/
          }
        else
          {
            if(retracement_percent>0)
              {
                signal_ADR_triggered(instrument);
                enter_signal=signal_retracement_after_ADR_triggered(instrument);
              }
            else
                enter_signal=signal_ADR_triggered(instrument);
            if(enter_signal>0 || enter_signal==DIRECTION_BIAS_IGNORE) 
              {
                ENUM_DIRECTION_BIAS ma_bias;
                ma_bias=signal_MA_better(instrument,current_bid);
                if(ma_bias==DIRECTION_BIAS_NEUTRALIZE && include_weaker_ma_setup) 
                  {
                    enter_signal=signal_bias_compare(enter_signal,signal_MA_worse(instrument));
                    if(reduce_risk_for_weaker_setups && enter_signal>0) 
                      {
                        reduced_risk=true;
                        //Print("reduced_risk=true");
                      }
                  }
                else 
                    enter_signal=signal_bias_compare(enter_signal,ma_bias);
              }
          }
        if((enter_signal>0 || enter_signal==DIRECTION_BIAS_IGNORE) && pullback_percent>0 && max_pending_orders_at_once>0)
          {
            if(pending_orders_open>=max_pending_orders_at_once) enter_signal=DIRECTION_BIAS_NEUTRALIZE;
          }
        if(enter_signal>0 && move_too_big_multiplier>0)
          {
            if(days_move_too_big(instrument)) enter_signal=DIRECTION_BIAS_NEUTRALIZE;
          }     
        if(compare_doubles(HOP_price-LOP_price,ADR_pts,digits)==-1) // the range between the HOP and LOP price should never be less than ADR_pts
          {
            enter_signal=DIRECTION_BIAS_NEUTRALIZE;
          }
        if(enter_signal>0 && past_x_days_same_trend>0)
          {
            if(enter_signal==DIRECTION_BIAS_BUY && is_over_extended_trend(instrument,past_x_days_same_trend,DOWNTREND,OPEN_MINUS_CLOSE_ABSOLUTE,NormalizeDouble(ADR_pts/2,digits),past_x_days_same_trend,true,current_bid)) enter_signal=DIRECTION_BIAS_BUY;
            else if(enter_signal==DIRECTION_BIAS_SELL && is_over_extended_trend(instrument,past_x_days_same_trend,UPTREND,OPEN_MINUS_CLOSE_ABSOLUTE,NormalizeDouble(ADR_pts/2,digits),past_x_days_same_trend,true,current_bid)) enter_signal=DIRECTION_BIAS_SELL;
            else enter_signal=DIRECTION_BIAS_NEUTRALIZE;
          }
        if(option2)
          {
            if(enter_signal>0) enter_signal=signal_counter_trend_trade(instrument,enter_signal);
          }
        if(enter_signal>0)
          {
            int seconds_span;
            if(!include_previous_day) 
              {
                if(x_hours>0) seconds_span=MathMin(int(current_time-days_open_time),int(x_hours*3600)); // ensure that the seconds span never spans to the previous day while also taking x_hours into account
                else seconds_span=int(current_time-days_open_time);
              }
            else 
              {
                if(x_hours>0) seconds_span=int(x_hours*3600);
                else seconds_span=86400; // Default to the past 24 hours. (There are 86400 seconds in a day.)
              }
            if(reverse_trade_direction==true)
              {
                if(enter_signal==DIRECTION_BIAS_BUY) enter_signal=DIRECTION_BIAS_SELL;
                else if(enter_signal==DIRECTION_BIAS_SELL) enter_signal=DIRECTION_BIAS_BUY;
              }
            // these if ane else if blocks will start to specifically analyze the buy or sell signals from the above filters
            if(enter_signal==DIRECTION_BIAS_BUY && long_allowed)
              {
                if(exit_opposite_signal) exit_all_trades_set(_exiting_max_slippage,ORDER_SET_SELL,magic);
                int long_trades_closed_today=count_orders (ORDER_SET_BUY, // should be first because the days_seconds variable was just calculated
                                                           magic,
                                                           MODE_HISTORY,
                                                           OrdersHistoryTotal()-1,
                                                           seconds_span,
                                                           current_time);
                int current_long_count=count_orders       (ORDER_SET_BUY, 
                                                           magic,
                                                           MODE_TRADES,
                                                           OrdersTotal()-1);
                //Print(longs_opened_today);
                //Print(current_long_count);         
                if(current_long_count<max_directional_trades_at_once &&
                  current_long_count+long_trades_closed_today<max_directional_trades_in_x_hours)
                  {
                    //if(!only_enter_on_new_bar || (only_enter_on_new_bar && is_new_M5_bar))
                    bool overbought_1=false;
                    bool overbought_2=false;
                    if(filter_over_extended_trends && over_extended_x_days>0)
                      {
                        RefreshRates();
                        overbought_1=is_over_extended_trend(instrument,over_extended_x_days,UPTREND,HIGH_MINUS_LOW,NormalizeDouble(ADR_pts*.75,digits),over_extended_x_days,false,current_bid);
                        overbought_2=is_over_extended_trend(instrument,over_extended_x_days,UPTREND,OPEN_MINUS_CLOSE_ABSOLUTE,NormalizeDouble(ADR_pts*.75,digits),over_extended_x_days,false,current_bid);           
                      }
                    if(overbought_1==false && overbought_2==false) 
                      {
                        //Print("try_to_enter_order: OP_BUY");
                        try_to_enter_order(OP_BUY,magic,entering_max_slippage_pips,instrument,reduced_risk,max_risky_trades,current_bid);
                        //uptrend_order_was_last=true;
                        //downtrend_order_was_last=false;
                      }
                    else print_and_email("Info","A potential "+instrument+" trade was prevented because the market was overbought.");
                  }
              }
            else if(enter_signal==DIRECTION_BIAS_SELL && short_allowed)
              {
                if(exit_opposite_signal) exit_all_trades_set(_exiting_max_slippage,ORDER_SET_BUY,magic);
                int short_trades_closed_today=count_orders(ORDER_SET_SELL, // should be first because the days_seconds variable was just calculated
                                                           magic,
                                                           MODE_HISTORY,
                                                           OrdersHistoryTotal()-1,
                                                           seconds_span,
                                                           current_time);
                int current_short_count=count_orders      (ORDER_SET_SELL,
                                                           magic,
                                                           MODE_TRADES,
                                                           OrdersTotal()-1);
                if(current_short_count<max_directional_trades_at_once &&
                  current_short_count+short_trades_closed_today<max_directional_trades_in_x_hours)
                  {
                    //if(!only_enter_on_new_bar || (only_enter_on_new_bar && is_new_M5_bar))
                    bool oversold_1=false;
                    bool oversold_2=false;
                    if(filter_over_extended_trends && over_extended_x_days>0)
                      {
                        RefreshRates();
                        oversold_1=is_over_extended_trend(instrument,over_extended_x_days,DOWNTREND,HIGH_MINUS_LOW,NormalizeDouble(ADR_pts*.75,digits),over_extended_x_days,false,current_bid);
                        oversold_2=is_over_extended_trend(instrument,over_extended_x_days,DOWNTREND,OPEN_MINUS_CLOSE_ABSOLUTE,NormalizeDouble(ADR_pts*.75,digits),over_extended_x_days,false,current_bid);
                      }
                    if(oversold_1==false && oversold_2==false) 
                      {
                        try_to_enter_order(OP_SELL,magic,entering_max_slippage_pips,instrument,reduced_risk,max_risky_trades,current_bid);
                        //Print("try_to_enter_order: OP_SELL");
                        //downtrend_order_was_last=true;
                        //uptrend_order_was_last=false;
                      }
                    else print_and_email("Info","A potential "+instrument+" trade was prevented because the market was oversold.");
                  }
              }
          }
      }
    else if(in_time_range==false)
      {
        ready=false; // this makes sure to set it to false so when the time is within the time range again, the ADR can get generated
        average_spread_yesterday=0; // do not change this from 0
        //ADR_pts=0; // ADR_pts can't be reset to 0 here because the trailing and breakeven functions need ADR_pts at all times
        if(DayOfWeek()==5 && is_new_M5_bar)
        // this Friday exit time code has to go before the daily exit time code in case the user wants to exit all trades on Fridays earlier than daily.
          {
            bool fri_time_to_exit=time_to_exit(current_time,fri_exit_time_hour,fri_exit_time_minute,gmt_hour_offset);
            if(fri_time_to_exit)
              {
                exit_all_trades_set(_exiting_max_slippage,ORDER_SET_ALL,magic); // this is the special case where you can exit open and pending trades based on a specified time (this should have been set to be outside of the trading time range)
              }
          }
        else if(exit_trades_EOD && is_new_M5_bar)
          {
            bool daily_time_to_exit=time_to_exit(current_time,exit_time_hour,exit_time_minute,gmt_hour_offset);
            if(daily_time_to_exit) 
              {
                exit_all_trades_set(_exiting_max_slippage,ORDER_SET_ALL,magic); // this is the special case where you can exit open and pending trades based on a specified time (this should have been set to be outside of the trading time range)
              }
          }
        if(_display_chart_objects)
          {
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
      }
    return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void reset_pivot_peak(string instrument)
  {
    // reset the LOP_price, HOP_price, and trends if the signal/setup is no longer valid
    string current_chart=Symbol();
    bool current_chart_matches=(current_chart==instrument);
    range_pts_calculation(OP_BUY,instrument,1082);
    range_pts_calculation(OP_SELL,instrument,1083);
    uptrend=false;
    downtrend=false;
    uptrend_time=-1;
    downtrend_time=-1;
    if(current_chart_matches)
      {
        ObjectSet(Symbol()+"_HOP",OBJPROP_WIDTH,1);
        ObjectSet(Symbol()+"_LOP",OBJPROP_WIDTH,1);      
      }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool set_point_multiplier(string instrument)
  {  
    int digits=(int)MarketInfo(instrument,MODE_DIGITS);
    if(auto_adjust_broker_digits==true && (digits==3 || digits==5))
      {
        Print("Your broker's rates have ",IntegerToString(digits)," digits after the decimal point. Therefore, to keep the math in the EA as it was intended, some pip values will be automatically multiplied by 10. You do not have to do anything.");
        point_multiplier=10;
      }
    else
        point_multiplier=1;
    return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool set_spread_divider()
  {  
    if(broker_is_oanda)
      {
        spread_divider=10;
      }
    else
      {
        spread_divider=1;
      }  
    return true;    
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_DIRECTION_BIAS signal_MA_better_2(string instrument,double current_bid) 
  {
    ENUM_DIRECTION_BIAS bias=DIRECTION_BIAS_NEUTRALIZE;
    if(moving_avg_period<=0)
        bias=DIRECTION_BIAS_IGNORE;
    else
      {
        double ma_price=iMA(instrument,PERIOD_M5,moving_avg_period,0,MODE_SMA,PRICE_MEDIAN,0);
        /*if(LOP_price<ma_price && HOP_price>ma_price) 
          {
            bias=DIRECTION_BIAS_NEUTRALIZE;
          }
        else 
          {*/
            if(uptrend && LOP_price<ma_price /*&& HOP_price<ma_price*/) // current_bid>ma_price && uptrend && LOP_price>ma_price
              { 
                //price_below_ma=true;
                //price_above_ma=false;
                //double point=MarketInfo(instrument,MODE_POINT);
                //double distance_pts=ma_price-HOP_price;
                //if(distance_pts>ma_range_pts*point*point_multiplier) bias=DIRECTION_BIAS_IGNORE;
                //else bias=DIRECTION_BIAS_NEUTRALIZE;

                bias=DIRECTION_BIAS_IGNORE;
              }
            else if(downtrend && HOP_price>ma_price /*&& LOP_price>ma_price*/)
              {
                //price_below_ma=false;
                //price_above_ma=true;
                //double point=MarketInfo(instrument,MODE_POINT);
                //double distance_pts=LOP_price-ma_price;
                //if(distance_pts>ma_range_pts*point*point_multiplier) bias=DIRECTION_BIAS_IGNORE;
                //else bias=DIRECTION_BIAS_NEUTRALIZE;

                bias=DIRECTION_BIAS_IGNORE;          
              }
            else bias=DIRECTION_BIAS_NEUTRALIZE;

          //}
      }
    return bias;
  }

ENUM_DIRECTION_BIAS signal_MA_better(string instrument,double current_bid) 
  {
    ENUM_DIRECTION_BIAS bias=DIRECTION_BIAS_NEUTRALIZE;
    if(moving_avg_period<=0)
        bias=DIRECTION_BIAS_IGNORE;
    else
      {
        double ma_price=iMA(instrument,PERIOD_M5,moving_avg_period,0,MODE_SMA,PRICE_MEDIAN,0);
        if(LOP_price<ma_price && HOP_price>ma_price) 
          {
            bias=DIRECTION_BIAS_NEUTRALIZE;
          }
        else
          {
            // _UJ_19pf_6dd_343t    control points, ADR_pts=65, moving_avg_period=500
            // _UJ_16pf_8dd_348t    tick data,      ADR_pts=65, moving_avg_period=500
            // _EU_16pf_7dd_345t    control points, ADR_pts=50, moving_avg_period=500
            // _EU_133pf_10dd_341t  tick data,      ADR_pts=50, moving_avg_period=500
            // _EJ_188pf_7dd_342t   control points, ADR_pts=65, moving_avg_period=500
            // _EJ_16pf_8dd_347t    tick data,      ADR_pts=65, moving_avg_period=500
            if(uptrend && HOP_price<ma_price) // current_bid>ma_price && uptrend && LOP_price>ma_price
              { 
                //price_below_ma=true;
                //price_above_ma=false;
                double point=MarketInfo(instrument,MODE_POINT);
                double distance_pts=ma_price-HOP_price;
                if(distance_pts>ma_range_pts*point*point_multiplier) 
                  bias=DIRECTION_BIAS_IGNORE;
                else 
                  bias=DIRECTION_BIAS_NEUTRALIZE;

                bias=DIRECTION_BIAS_IGNORE;
              }
            else if(downtrend && LOP_price>ma_price)
              {
                //price_below_ma=false;
                //price_above_ma=true;
                double point=MarketInfo(instrument,MODE_POINT);
                double distance_pts=LOP_price-ma_price;
                if(distance_pts>ma_range_pts*point*point_multiplier) 
                  bias=DIRECTION_BIAS_IGNORE;
                else 
                  bias=DIRECTION_BIAS_NEUTRALIZE;
                bias=DIRECTION_BIAS_IGNORE;          
              }
            else bias=DIRECTION_BIAS_NEUTRALIZE;

          }
      }
    return bias;
  }



ENUM_DIRECTION_BIAS _signal_MA_better_test_3(string instrument,double current_bid) 
  {
    ENUM_DIRECTION_BIAS bias=DIRECTION_BIAS_NEUTRALIZE;
    if(moving_avg_period<=0)
        bias=DIRECTION_BIAS_IGNORE;
    else
      {
        int ma_shift=0;
        int ma_index=0;
        double ma_price=iMA(instrument,PERIOD_M5,moving_avg_period,ma_shift,MODE_SMA,PRICE_MEDIAN,ma_index);
        if(LOP_price<ma_price && HOP_price>ma_price) 
          {
            bias=DIRECTION_BIAS_NEUTRALIZE;
          }
        else
          {
            if(current_bid<ma_price) // current_bid>ma_price && uptrend && LOP_price>ma_price
              { 
                //price_below_ma=true;
                //price_above_ma=false;
                double point=MarketInfo(instrument,MODE_POINT);
                double distance_pts=ma_price-current_bid;
                if(distance_pts>ma_range_pts*point*point_multiplier) bias=DIRECTION_BIAS_BUY;
                else bias=DIRECTION_BIAS_NEUTRALIZE;
                
             }
            else if(current_bid>ma_price)
              {
                //price_below_ma=false;
                //price_above_ma=true;
                double point=MarketInfo(instrument,MODE_POINT);
                double distance_pts=current_bid-ma_price;
                if(distance_pts>ma_range_pts*point*point_multiplier) bias=DIRECTION_BIAS_SELL;
                else bias=DIRECTION_BIAS_NEUTRALIZE;
                
              }
            else bias=DIRECTION_BIAS_NEUTRALIZE;
          }
      }
    return bias;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_DIRECTION_BIAS signal_MA_worse(string instrument) 
  {
    ENUM_DIRECTION_BIAS bias=DIRECTION_BIAS_NEUTRALIZE;
    if(moving_avg_period<=0 || ma_multiplier<=0)
      {
        bias=DIRECTION_BIAS_IGNORE;
      }      
    else
      {
        int ma_shift=0;
        int ma_index=0;
        double ma2_price=iMA(instrument,PERIOD_M5,600,ma_shift,MODE_SMA,PRICE_MEDIAN,ma_index);
        if(LOP_price<ma2_price && HOP_price>ma2_price) // First check if the lower quality setup with reduced risk is valid.
          {
            // _EJ_1.26pf_10.5dd_432t    tick data,      ADR_pts=65, moving_avg_period=600
            bias=DIRECTION_BIAS_IGNORE;
            //Print("a worse trade should happen");
          }
      }
    return bias;  
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double get_previous_days_bar_info(string instrument,ENUM_BAR_POINTS bar_point,ENUM_PRICE_OR_TIME price_or_time)
  {
    static double   high_price,low_price,open_price,close_price;
    static datetime high_time,low_time,open_time,close_time;
    static datetime last_date_checked=-1;
    datetime        date=round_down_to_hours(iTime(instrument,PERIOD_D1,0));
    int             previous_day=TimeDayOfWeek(iTime(instrument,PERIOD_D1,1));
    double value=-1;
    int bar=1;
    if(previous_day==0) bar=2;
    if(date!=last_date_checked && (TimeHour(date)==0 && TimeMinute(TimeCurrent())<10))
      {
        //high_price=iHigh(instrument,PERIOD_D1,bar);
        int high_bar=iHighest(instrument,PERIOD_M5,MODE_HIGH,24*12,bar);
        high_price=iHigh(instrument,PERIOD_M5,high_bar);
        high_time=iTime(instrument,PERIOD_M5,high_bar);

        //low_price=iLow(instrument,PERIOD_D1,bar);
        int low_bar=iLowest(instrument,PERIOD_M5,MODE_LOW,24*12,bar);
        low_price=iLowest(instrument,PERIOD_M5,low_bar);
        low_time=iTime(instrument,PERIOD_M5,low_bar);

        open_price=iOpen(instrument,PERIOD_D1,1);
        open_time=round_down_to_hours(iTime(instrument,PERIOD_D1,bar));

        close_price=iClose(instrument,PERIOD_D1,1);
        close_time=open_time+(3600*24)-1;

        last_date_checked=date;
      }
    switch(bar_point)
      {
        case myOPEN:
          if(price_or_time==myTIME) value=(double)open_time;   
          else if(price_or_time==myPRICE) value=open_price;
          break;
        case myHIGH:
          if(price_or_time==myTIME) value=(double)high_time;   
          else if(price_or_time==myPRICE) value=high_price;
          break;
        case myLOW:
          if(price_or_time==myTIME) value=(double)low_time;   
          else if(price_or_time==myPRICE) value=low_price;
          break;
        case myCLOSE:
          if(price_or_time==myTIME) value=(double)close_time;   
          else if(price_or_time==myPRICE) value=close_price;
      }
    return value;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_DIRECTION_BIAS signal_counter_trend_trade(string instrument,ENUM_DIRECTION_BIAS bias)
  {
    if(bias>0)
      {
        double high_price=get_previous_days_bar_info(instrument,myHIGH,myPRICE);
        double low_price=get_previous_days_bar_info(instrument,myLOW,myPRICE);
        if(high_price-low_price>=ADR_pts/2)
          {
            double open_price=get_previous_days_bar_info(instrument,myOPEN,myPRICE);
            //datetime open_time=get_previous_days_bar_info(instrument,myOPEN,myTIME);
            double close_price=get_previous_days_bar_info(instrument,myCLOSE,myPRICE);
            //datetime close_time=(datetime)get_previous_days_bar_info(instrument,myCLOSE,myTIME);
            datetime high_time=(datetime)get_previous_days_bar_info(instrument,myHIGH,myTIME);
            datetime low_time=(datetime)get_previous_days_bar_info(instrument,myLOW,myTIME);
            if(bias==DIRECTION_BIAS_BUY)
              {
                if(open_price>close_price && high_time<low_time)  
                  return DIRECTION_BIAS_NEUTRALIZE;
                else 
                  return DIRECTION_BIAS_BUY;
              }
            else if(bias==DIRECTION_BIAS_SELL)
              {
                if(open_price<close_price && high_time>low_time) 
                  return DIRECTION_BIAS_NEUTRALIZE;
                else 
                  return DIRECTION_BIAS_SELL;
              }
          }
      }
    return DIRECTION_BIAS_NEUTRALIZE;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_over_extended_trend(string instrument,int days_to_check,ENUM_TREND trend,ENUM_RANGE range,double points_threshold,int num_to_be_true,bool dont_analyze_today,double bid_price)
  {
    static int      new_days_to_check=0;
    static datetime last_date_checked=-1;
    datetime        date=round_down_to_days(iTime(instrument,PERIOD_D1,0));
    int             digits=(int)MarketInfo(instrument,MODE_DIGITS);
    //double        bid_price=MarketInfo(instrument,MODE_BID);
    bool            over_extended=false; // keep as false
    int             uptrend_count=0, downtrend_count=0;
    int             sat_sun_count=0;
    int             lower_index=(int)dont_analyze_today;
    if(date!=last_date_checked) // get the new value of the static sunday_count the first time it is run or if it is a new day
      {
        new_days_to_check=0;
        for(int i=lower_index;i<=days_to_check-1+lower_index;i++)
          {
            int day=TimeDayOfWeek(iTime(instrument,PERIOD_D1,i));
            if(day==0 || day==6) // count Sundays and Saturdays
              {
                sat_sun_count++;
              }
          }
        last_date_checked=date;
        new_days_to_check=sat_sun_count+days_to_check;
      }
    if(trend==UPTREND)
      {
        int upper_index=new_days_to_check-1+lower_index;
        for(int i=lower_index;i<=upper_index;i++) // days_to_check should be past days to check + today
          {
            bool closed_bar=(i>0);
            double open_price=iOpen(instrument,PERIOD_D1,i), close_price=iClose(instrument,PERIOD_D1,i);
            if(new_days_to_check>days_to_check) // if there have been Sundays and/or Satursdays identified in this range
              {
                int day=TimeDayOfWeek(iTime(instrument,PERIOD_D1,i));
                if(day==0 || day==6) break; // if the bar is Sunday or Saturday, skip this day            
              }
            double days_range=0;
            if(range==HIGH_MINUS_LOW)
              {
                if(closed_bar) days_range=iHigh(instrument,PERIOD_D1,i)-iLow(instrument,PERIOD_D1,i);
                else days_range=bid_price-iLow(instrument,PERIOD_D1,i);
              }
            else if(range==OPEN_MINUS_CLOSE_ABSOLUTE)
              {
                if(closed_bar) days_range=close_price-open_price;
                else days_range=bid_price-open_price; // can be negative
              }
            if(days_range>=points_threshold) // only positive day_ranges pass this point // TODO: use compare_doubles()?
              {
                if(closed_bar)
                  {
                    double previous_days_close=iClose(instrument,PERIOD_D1,i+1);
                    if(close_price>previous_days_close) uptrend_count++;// TODO: use compare_doubles()?
                    else downtrend_count++;
                  }
                else
                  {
                    if(bid_price>open_price) uptrend_count++;  // TODO: use compare_doubles()?
                    else downtrend_count++;
                  }
              }
          }
        if(uptrend_count>=num_to_be_true) over_extended=true;
      }
    else if(trend==DOWNTREND)
      {
        int upper_index=new_days_to_check-1+lower_index;
        for(int i=lower_index;i<=upper_index;i++) // days_to_check should be past days to check + today
          {
            bool closed_bar=(i>0);
            double open_price=iOpen(instrument,PERIOD_D1,i), close_price=iClose(instrument,PERIOD_D1,i);
            if(new_days_to_check>days_to_check) // if there have been Sundays and/or Satursdays identified in this range
              {
                int day=TimeDayOfWeek(iTime(instrument,PERIOD_D1,i));
                if(day==0 || day==6) break; // if the bar is Sunday or Saturday, skip this day
              }
            double days_range=0;
            if(range==HIGH_MINUS_LOW) 
              {
                if(closed_bar) days_range=iHigh(instrument,PERIOD_D1,i)-iLow(instrument,PERIOD_D1,i);
                else days_range=iHigh(instrument,PERIOD_D1,i)-bid_price;
              }
            else if(range==OPEN_MINUS_CLOSE_ABSOLUTE)
              {
                if(closed_bar) days_range=open_price-close_price;
                else days_range=open_price-bid_price;
              }
            if(days_range>=points_threshold) // only positive day_ranges pass this point // TODO: use compare_doubles()?
              { 
                if(closed_bar)
                  {
                    double previous_days_close=iClose(instrument,PERIOD_D1,i+1);
                    if(close_price<previous_days_close) downtrend_count++; // TODO: use compare_doubles()?
                    else uptrend_count++;               
                  }
                else
                  {
                    if(open_price>bid_price) downtrend_count++; // TODO: use compare_doubles()?
                    else uptrend_count++;
                  }  
              }
          }
        if(downtrend_count>=num_to_be_true) over_extended=true;
      }
    return over_extended;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/*bool past_x_D1_bars_down_2(string instrument,int x_bars)
  {
    int count=0;
    bool two_day_weekend=false;
    for(int i=1;i<=x_bars;i++)
      {
        int new_i=i;
        int day=TimeDayOfWeek(iTime(instrument,PERIOD_D1,i));
        int day_before=TimeDayOfWeek(iTime(instrument,PERIOD_D1,i+1));
        if((day==0 && day_before==6) || two_day_weekend)
          {
            two_day_weekend=true;
            new_i++;
          }
        if(day==0 || day==6)
          {
            new_i++;
          } 
        if(iOpen(instrument,PERIOD_D1,new_i)>iClose(instrument,PERIOD_D1,new_i))
          {
            count++;
          }
      }
    if(count==x_bars) return true;
    return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool past_x_D1_bars_down(string instrument,int x_bars)
  {
    int count=0;
    for(int i=1;i<=x_bars;i++)
      {
        if(iOpen(instrument,PERIOD_D1,i)<iClose(instrument,PERIOD_D1,i))
          {
            count++;
          }
      }
    if(count==x_bars) return true;
    return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool past_x_D1_bars_up(string instrument,int x_bars)
  {
    int count=0;
    for(int i=1;i<=x_bars;i++)
      {
        if(iOpen(instrument,PERIOD_D1,i)<iClose(instrument,PERIOD_D1,i))
          {
            count++;
          }
      }
    if(count==x_bars) return true;
    return false;
  }*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_DIRECTION_BIAS signal_ADR_triggered(string instrument)
  {
    ENUM_DIRECTION_BIAS signal=DIRECTION_BIAS_NEUTRALIZE;
    /*if(option3) boo=price_below_ma;
    else  boo=uptrend_order_was_last;*/
    if(/*uptrend_order_was_last==false || retracement_percent==0*/ uptrend==false)
      {
        //if(is_new_M5_bar) Print("uptrend_ADR_threshold_met_price is running");
        RefreshRates();
        if(uptrend_ADR_threshold_met_price(instrument,false)==true)
          {
            return signal=DIRECTION_BIAS_BUY; // FYI, when using the signal_retracement_pullback_after_ADR_triggered for signals, this return value has absolutely no affect.
          }
      }
    // for a buying signal, take the level that adr was triggered and subtract the pullback_pips to get the pullback_entry_price
    // if the pullback_entry_price is met or exceeded, signal = TRADE_SIGNAL_BUY
    if(/*downtrend_order_was_last==false || retracement_percent==0*/ downtrend==false)
      {
        //if(is_new_M5_bar) Print("downtrend_ADR_threshold_met_price is running");
        RefreshRates();
        if(downtrend_ADR_threshold_met_price(instrument,false)==true) 
          {
            return signal=DIRECTION_BIAS_SELL; // FYI, when using the signal_retracement_pullback_after_ADR_triggered for signals, this return value has absolutely no affect.
          }
      }
    return signal;
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+  
/*ENUM_DIRECTION_BIAS _signal_ADR_triggered_test(string instrument)
  {
    ENUM_DIRECTION_BIAS signal=DIRECTION_BIAS_NEUTRALIZE;
    if((price_below_ma && uptrend_order_was_last==false) || retracement_percent==0)
      {
        RefreshRates();
        if(uptrend_ADR_threshold_met_price(instrument,false)==true)
          {
            return signal=DIRECTION_BIAS_BUY; // FYI, when using the signal_retracement_pullback_after_ADR_triggered for signals, this return value has absolutely no affect.
          }
      }
    else if((price_above_ma && downtrend_order_was_last==false) || retracement_percent==0)
      {
        //if(is_new_M5_bar) Print("downtrend_ADR_threshold_met_price is running");
        RefreshRates();
        if(downtrend_ADR_threshold_met_price(instrument,false)==true) 
          {
            return signal=DIRECTION_BIAS_SELL; // FYI, when using the signal_retracement_pullback_after_ADR_triggered for signals, this return value has absolutely no affect.
          }
      }
    return signal;
   }*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_DIRECTION_BIAS signal_retracement_after_ADR_triggered(string instrument)
  {
    ENUM_DIRECTION_BIAS signal=DIRECTION_BIAS_NEUTRALIZE;
    if(uptrend_retracement_met_price(instrument)==true) signal=DIRECTION_BIAS_BUY;
    //if(signal==DIRECTION_BIAS_BUY) Print("buy signal");
    if(downtrend_retracement_met_price(instrument)==true) signal=DIRECTION_BIAS_SELL;
    //Print("signal_retracement_pullback_after_ADR_triggered returned: ",signal);
    return signal;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Checks for the entry of orders
/*ENUM_DIRECTION_BIAS signal_entry(string instrument,ENUM_SIGNAL_SET signal_set) // gets called for every tick
  {
    ENUM_DIRECTION_BIAS signal=DIRECTION_BIAS_NEUTRALIZE;
    Add 1 or more entry signals below. 
    With more than 1 signal, you would follow this code using the signal_compare function. 
    "signal=signal_compare(signal,signal_pullback_after_ADR_triggered());"
    As each signal is compared with the previous signal, the signal variable will change and then the final signal wil get returned.
    
    if(signal_set==SIGNAL_SET_1)
      {
        signal=signal_bias_compare(signal,signal_MA(instrument),false);
        return signal;
      }
    if(signal_set==SIGNAL_SET_2)
      {
        return signal;
      }
    else return DIRECTION_BIAS_NEUTRALIZE;
  }*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Checks for the exit of orders
/*int signal_exit(string instrument,ENUM_SIGNAL_SET signal_set)
  {
    int signal=DIRECTION_BIAS_NEUTRALIZE;
     Add 1 or more entry signals below. 
    With more than 1 signal, you would follow this code using the signal_compare function. 
    "signal=signal_compare(signal,signal_pullback_after_ADR_triggered());"
    As each signal is compared with the previous signal, the signal variable will change and then the final signal wil get returned.
    
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
  }*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_DIRECTION_BIAS signal_bias_compare(ENUM_DIRECTION_BIAS current_bias,ENUM_DIRECTION_BIAS added_bias,bool exit_when_buy_and_sell=false) 
  {
    // signals are evaluated two at a time and the result will be used to compared with other signals until all signals are compared
    if     (current_bias==DIRECTION_BIAS_VOID          || added_bias==DIRECTION_BIAS_VOID)           return DIRECTION_BIAS_VOID;
    else if(current_bias==DIRECTION_BIAS_NEUTRALIZE    || added_bias==DIRECTION_BIAS_NEUTRALIZE)     return DIRECTION_BIAS_NEUTRALIZE;
    else if(current_bias==DIRECTION_BIAS_IGNORE)                                                     return added_bias;
    else if(added_bias  ==DIRECTION_BIAS_IGNORE)                                                     return current_bias;
    else if(current_bias==DIRECTION_BIAS_NOT_BUY       && added_bias==DIRECTION_BIAS_BUY)            return DIRECTION_BIAS_NEUTRALIZE;
    else if(current_bias==DIRECTION_BIAS_BUY           && added_bias==DIRECTION_BIAS_NOT_BUY)        return DIRECTION_BIAS_NEUTRALIZE;
    else if(current_bias==DIRECTION_BIAS_NOT_SELL      && added_bias==DIRECTION_BIAS_SELL)           return DIRECTION_BIAS_NEUTRALIZE;
    else if(current_bias==DIRECTION_BIAS_SELL          && added_bias==DIRECTION_BIAS_NOT_SELL)       return DIRECTION_BIAS_NEUTRALIZE;
    // at this point, the only two options left are if they are both buy, both sell, or buy and sell
    else if(added_bias!=current_bias) // if one bias is bullish and the other is bearish
      {
        if(exit_when_buy_and_sell) return DIRECTION_BIAS_VOID;
        else return DIRECTION_BIAS_NEUTRALIZE;
      }
    return added_bias; // at this point, the added_bias and current_bias must be the same buy or sell same signal so it can get returned
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ran(bool result,bool added_result=true)
  {
    if(result==false || added_result==false) return false;
    else return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool boolean_compare(bool boolean1,bool boolean2=true)
  {
    if(boolean1==false || boolean2==false) return false;
    else return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Neutralizes situations where there is a conflict between the entry and exit signal.
// TODO: This function is not yet being called. Since the entry and exit signals are passed by reference, these paremeters would need to be prepared in advance and stored in variables prior to calling the function.
/*void signal_manage(ENUM_DIRECTION_BIAS &entry,ENUM_DIRECTION_BIAS &exit)
  {
    if(exit==DIRECTION_BIAS_VOID)                                  entry=DIRECTION_BIAS_NEUTRALIZE;
    if(exit==DIRECTION_BIAS_BUY && entry==DIRECTION_BIAS_SELL)     entry=DIRECTION_BIAS_NEUTRALIZE;
    if(exit==DIRECTION_BIAS_SELL && entry==DIRECTION_BIAS_BUY)     entry=DIRECTION_BIAS_NEUTRALIZE;
  }*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int get_string_integer(string string1)
  {
    int i, combined_letter_int=0, letter_int=0;
    for(i=0; i<StringLen(string1); i++)
      {
        letter_int=StringGetChar(string1,i);
        //Print(combined_letter_int,"+",letter_int);
        combined_letter_int=(combined_letter_int<<5)+combined_letter_int+letter_int; // << Bitwise Left shift operator shifts all bits towards left by certain number of specified bits.
      }
    return combined_letter_int;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int set_magic_num(string instrument, ENUM_SIGNAL_SET)
  {
   int instrument_int=get_string_integer(instrument);
   return(instrument_int);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_market_open_today(string instrument,datetime current_time)
  {
    //int digits=(int)MarketInfo(instrument,MODE_DIGITS);
    bool market_open_today;
    market_open_today=iOpen(instrument,PERIOD_D1,0)>0 && iOpen(instrument,PERIOD_D1,0)!=NULL;
    market_open_today=boolean_compare(market_open_today,MarketInfo(instrument,MODE_TRADEALLOWED));
    //Print("market_open_today: ",market_open_today);
    return market_open_today;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_day_to_trade()
  {
    if(Month()==1)
      {
        if(DayOfYear()>=1 && DayOfYear()<=2)
          {
            return false;
          }     
      }
    else if(Month()==12)
      {
        if(DayOfYear()>=357 && DayOfYear()<=365)
          {
            return false;
          }    
      }
    return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool in_time_range(datetime time,int start_hour,int start_min,int end_hour,int end_min,int _fri_end_time_hr, int _fri_end_time_min, int gmt_offset,double bid_price)
  {
    string current_chart=Symbol();
    //double bid_price=MarketInfo(current_chart,MODE_BID);
    int    day=TimeDayOfWeek(time);
    if(day==0 || day==6) 
        return false; // if the broker's server time says it is Sunday or Saturday, you are not in your trading time range
    else if(day==5)
      {
        if(trade_friday==false) return false;
        end_hour=_fri_end_time_hr;
        end_min=_fri_end_time_min;
      }
    if(gmt_offset!=0) 
      {
        start_hour+=gmt_offset;
        end_hour+=gmt_offset;
        //fri_end_time_hr+=gmt_offset;
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
    if(display_chart_objects)
      {
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
        if(display_chart_objects)
          {
            string current_chart=Symbol();
            double bid_price=MarketInfo(current_chart,MODE_BID);
            string tte_text=current_chart+"_time_to_exit";
            if(ObjectFind(tte_text)<0)
              {
                ObjectCreate(tte_text,OBJ_VLINE,0,TimeCurrent(),bid_price);
                ObjectSet(tte_text,OBJPROP_COLOR,clrRed);
                ObjectSet(tte_text,OBJPROP_STYLE,STYLE_DASH);            
              }
            else
              {
                ObjectMove(tte_text,0,TimeCurrent(),bid_price); // TODO: this statement will run for every single instrument
              }  
          } 
        return true; // this will only give the signal to exit for every tick for 1 minute per day
      }
    else return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool set_gmt_offset(string instrument,datetime current_time,int coming_from) // Automatic gmt_offset_hour detection based on the broker's server times. The offset can vary between 0 and 4 depending on the time of year.
  {
    // keep these static variables in this scope
    static datetime last_date_variable_modified=myNULL; // keep as static and myNULL (aka -1)
    datetime        date=iTime(instrument,PERIOD_D1,0);
    int             day=TimeDayOfWeek(current_time);
    bool            other_criteria=gmt_hour_offset_is_NULL || last_date_variable_modified==myNULL;
    bool            new_day=is_new_D1_bar || is_new_custom_D1_bar;
    if((day<=1 && date!=last_date_variable_modified && new_day) || other_criteria)
      {
        int  gmt_offset_required=myNULL; // it is static because brokers probably never change their server time policy
        int  _gmt_hour_offset=100; // keep at 100 because that is a value that gmt_hour_offset will never be
        bool variable_modified=false;
        if(automatic_gmt_offset==false)
          {
            _gmt_hour_offset=0;
            variable_modified=true;
          }
        else
          {
            if(new_day || other_criteria)
              {
                if(gmt_hour_offset_is_NULL)     Print("set_gmt_offset: is_new_D1_bar or is_new_D1_bar and gmt_hour_offset is NULL");
                if(gmt_offset_required==myNULL) Print("set_gmt_offset: is_new_D1_bar or is_new_D1_bar and gmt_offset_required is NULL"); 
                if(is_new_custom_W1_bar)        Print("set_gmt_offset: it is a new week so set_gmt_offset will be generated");             
              }
            // determine if a gmt offset is required
            if(day==1 && TimeDayOfWeek(iTime(instrument,PERIOD_D1,1))==5) // This condition is true when the chart goes from having a GMT offset to not having one.
              {
                gmt_offset_required=false;
                if(print_time_info) Print("A gmt_hour_offset that ==0 is required (1)");
              }
            else if(day==0 && is_new_D1_bar && is_new_custom_D1_bar && TimeHour(current_time)!=0) // This condition is true when the chart goes from not having a GMT offset to having one.
              {
                gmt_offset_required=true;
                if(print_time_info) Print("A gmt_hour_offset that !=0 is required (1)");
              }
            else if((day==1 && new_day) || other_criteria)
              {
                for(int i=0;i<16;i++)
                  {
                    if(gmt_offset_required<=0)
                      {
                        if(TimeDayOfWeek(iTime(instrument,PERIOD_D1,i))==0) // if the current bar is Sunday
                          {
                            gmt_offset_required=true;
                            if(print_time_info) Print("A gmt_hour_offset that !=0 is required (2)");
                          }
                      }
                  }
                if(gmt_offset_required<=0) // if gmt_offset_required is still false after the loop
                  {
                    gmt_offset_required=false;
                    if(print_time_info) Print("A gmt_hour_offset that ==0 is required (2)");  
                  }
              }
            else print_and_email("Error","set_gmt_offset: The code failed to determine if gmt_offset_required is true or false.");
            // determine if there is an issue with what the user sees on the chart and what is actually on the chart
            if(gmt_offset_required==true) // if it is Sunday or Monday (but only running the code one time per day) or if it is the first time the gmt offset was attempted to be generated
              {
                //Print("gmt_offset_required: ",gmt_offset_required);
                if(gmt_offset_visible==false) 
                  {
                    print_and_email("Error","set_gmt_offset: A GMT offset was detected on the broker's "+instrument+" chart but the user indicates that there isn't supposed to be one. Coming from: "+IntegerToString(coming_from));
                    return false;
                  }
                datetime sundays_bar_time=0;
                for(int i=0;i<16;i++)
                  {
                    if(variable_modified==false)
                      {
                        datetime current_bar_time=iTime(instrument,PERIOD_D1,i);
                        int      day_of_week=TimeDayOfWeek(current_bar_time);   
                        int      absolute_gmt_offset=0;                      
                        if(day_of_week==0)
                          {
                            sundays_bar_time=current_bar_time;
                            int market_start_hour=get_sundays_start_hour(instrument,sundays_bar_time,1);
                            //Print("current_bar_time=",TimeToString(current_bar_time));
                            //Print("sundays_bar_time=",TimeToString(sundays_bar_time));
                            absolute_gmt_offset=24-market_start_hour;
                            //Print("temp_gmt_offset=",temp_gmt_offset);                
                          }
                        else 
                          {
                            datetime previous_bar_time=iTime(instrument,PERIOD_D1,i+1);
                            if(day_of_week==1 && TimeDayOfWeek(previous_bar_time)==0) // if the current bar is Monday and the previous bar is Sunday
                              {
                                sundays_bar_time=previous_bar_time;
                                if(current_bar_time>sundays_bar_time) // this is so absolute_gmt_offset returns a positive only and current_bar_time really is > sundays_bar_time
                                  {
                                    int market_start_hour=get_sundays_start_hour(instrument,sundays_bar_time,1);
                                    sundays_bar_time+=(market_start_hour*3600);
                                    //Print("current_bar_time=",TimeToString(current_bar_time));
                                    //Print("sundays_bar_time=",TimeToString(sundays_bar_time));
                                    absolute_gmt_offset=int((current_bar_time-sundays_bar_time)/3600);
                                    //Print("temp_gmt_offset=",temp_gmt_offset);                                         
                                  }
                              }
                          }
                        if(absolute_gmt_offset>0)
                          {
                            _gmt_hour_offset=-absolute_gmt_offset;
                            variable_modified=true;
                          }
                      }
                  }
              }
            else if(gmt_offset_required==false)
              {
                //Print("gmt_offset_required: ",gmt_offset_required);
                if(gmt_offset_visible==true) 
                  {
                    int current_gmt_offset=gmt_hour_offset;
                    //print_and_email("Info","set_gmt_offset: gmt_hour_offset will continue to be: "+IntegerToString(gmt_hour_offset));
                    if(gmt_hour_offset_is_NULL==false && day==1 && new_day) print_and_email("Warning","set_gmt_offset: A GMT offset was not detected on the broker's "+instrument+" chart but the user indicates that there is supposed to be one. Either this could be normal (due to a recent Daylight Savings Time event and the charts being in a period of time that does not require a gmt offset) or it could be an Error. Coming from: "+IntegerToString(coming_from));
                    else if(gmt_hour_offset_is_NULL) print_and_email("Important Info","set_gmt_offset: gmt_hour_offset is NULL and is about to be changed to 0 for "+instrument+" because a gmt offset was not detected recently but the user indicates there is supposed to be one"); // this should run before gmt_hour_offset_is_NULL assigned to false
                  }
                _gmt_hour_offset=0;
                variable_modified=true;
              }
            else if(gmt_offset_required==myNULL)
              {
                print_and_email("Error","set_gmt_offset: gmt_offset_required="+IntegerToString(gmt_offset_required)+" for "+instrument);
              }
          }
        if(variable_modified && _gmt_hour_offset!=100) 
          {
            if(_gmt_hour_offset!=0 && MathMod(_gmt_hour_offset,1)!=0) 
              {
                //Print("set_gmt_offset: returned false 1");
                print_and_email("Error","set_gmt_offset: gmt_hour_offset is not divisible by 1 so that is strange");
                return false; // stop the algorithm if the gmt_hour_offset is not completely divisible by .5
              }
            if(MathAbs(_gmt_hour_offset)>5) 
              {
                print_and_email("Error","set_gmt_offset: gmt_hour_offset was attempted to be set to "+IntegerToString(_gmt_hour_offset)+" so that is strange");
                return false; // something is wrong if these to boolean variables do not equal to each other and it is recommended to abort the algorithm
              }
            int current_gmt_offset=gmt_hour_offset;
            gmt_hour_offset=_gmt_hour_offset;
            gmt_hour_offset_is_NULL=false;
            last_date_variable_modified=date;
            if(current_gmt_offset!=gmt_hour_offset) 
              { 
                is_new_custom_D1_bar=is_new_custom_D1_bar(instrument,current_time); // immediately get the is_new_custom_D1_bar boolean variable since the gmt_hour_offset was confirmed to have been changed. This way is_new_custom_week will run soon and return true ASAP
                print_and_email("Important Info","set_gmt_offset: gmt_hour_offset was "+IntegerToString(current_gmt_offset)+" but has now been changed to: "+IntegerToString(_gmt_hour_offset)); 
              }
          }
        else
          { 
            string market_open="";
            if(is_market_open_today(instrument,current_time)==false) market_open=" The market was not open today.";
            last_date_variable_modified=myNULL; // set this variable to NULL so that, on days that are not Sunday or Monday, the code in ths function can try to assign a value to gmt_hour_offset
            if(!gmt_hour_offset_is_NULL) print_and_email("Error","set_gmt_offset: gmt_hour_offset was not modified. Instead, it was kept the same value as before while the algorithm continues to run.");
            else print_and_email("Error","set_gmt_offset: gmt_hour_offset was not modified. gmt_hour_offset_is_NULL was true when attempting to modify."+market_open);
            
          }
      }
    return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime round_down_to_hours(datetime time)
  {
    return StringToTime(StringConcatenate(IntegerToString(TimeYear(time)),".",
                                          IntegerToString(TimeMonth(time),2,0),".",
                                          IntegerToString(TimeDay(time),2,0)," ",
                                          IntegerToString(TimeHour(time),2,0)+":00"));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime round_down_to_days(datetime time)
  {
    return StringToTime(StringConcatenate(IntegerToString(TimeYear(time)),".",
                                          IntegerToString(TimeMonth(time),2,0),".",
                                          IntegerToString(TimeDay(time),2,0)," ",
                                          "00:00"));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_new_M5_bar(string instrument,bool wait_for_next_bar=false)
  {
    static datetime M5_bar_time=0;
    static double   M5_open_price=0;
    datetime        M5_current_bar_open_time=iTime(NULL,PERIOD_M5,0);
    double          M5_current_bar_open_price=iOpen(NULL,PERIOD_M5,0);
    int             digits=(int)MarketInfo(instrument,MODE_DIGITS);
    if(M5_bar_time==0) // If it is the first time the function is called or it is the start of a new bar. This could be after the open time (aka in the middle) of a bar.
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
        //Print("new M5 2");
        return true;
      }
    else if(TimeCurrent()-M5_bar_time>300) // sometimes a new bar is not recognized, so this will make sure it is
      {
        M5_bar_time=M5_current_bar_open_time;
        M5_open_price=M5_current_bar_open_price;
        //Print("NEW M5 3");
        return true; 
      }  
    else return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_new_H1_bar(string instrument,bool wait_for_next_bar) // This may not result to true exactly on the hour but may result to true a few minutes after the hour. But that is okay.
  {
    static datetime H1_bar_time=0;
    static double   H1_open_price=0;
    datetime        H1_current_bar_open_time=iTime(NULL,PERIOD_H1,0);
    double          H1_current_bar_open_price=iOpen(NULL,PERIOD_H1,0);
    int             digits=(int)MarketInfo(instrument,MODE_DIGITS);
    if(H1_bar_time==0) // If it is the first time the function is called or it is the start of a new bar. This could be after the open time (aka in the middle) of a bar. FYI, this function never returns true in the first hour of when the EA get's turned on.
      {
        H1_bar_time=H1_current_bar_open_time;
        hours_open_time=H1_current_bar_open_time; // there is no harm in assigning this variable at this point
        H1_open_price=H1_current_bar_open_price;
        if(wait_for_next_bar) return false;
        else 
          {
            //if(print_time_info) Print("new hour (1)");
            return true; 
          }  
      }
    else if(H1_current_bar_open_time>H1_bar_time && compare_doubles(H1_open_price,H1_current_bar_open_price,digits)!=0) // if the opening time and price of this bar is different than the opening time and price of the previous one
      {
        //if(H1_current_bar_open_time-H1_bar_time>3900 && DayOfWeek()!=0) Print("THE PREVIOUS H1 BAR WAS NOT DETECTED 1");
        H1_bar_time=H1_current_bar_open_time; // assuring the true value only gets returned for 1 tick and not the very next ones
        hours_open_time=H1_current_bar_open_time;
        H1_open_price=H1_current_bar_open_price; // assuring the true value only gets returned for 1 tick and not the very next ones
        //if(print_time_info) Print("new hour (2)");
        return true;
      }
    else if(TimeCurrent()-H1_bar_time>3600) // sometimes a new bar is not recognized, so this will make sure it is
      {
        //if(TimeCurrent()-H1_bar_time>3900 && DayOfWeek()!=0) Print("THE PREVIOUS H1 BAR WAS NOT DETECTED 2");
        H1_bar_time=H1_current_bar_open_time;
        H1_open_price=H1_current_bar_open_price;
        //if(print_time_info) Print("NEW HOUR (3)");
        return true; 
      }  
    else return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_new_D1_bar(string instrument,bool wait_for_next_bar)
  {
    static datetime D1_bar_time=0;
    static double   D1_open_price=0;
    datetime        D1_current_bar_open_time=iTime(instrument,PERIOD_D1,0);
    double          D1_current_bar_open_price=iOpen(instrument,PERIOD_D1,0);
    int             digits=(int)MarketInfo(instrument,MODE_DIGITS);
    if(D1_bar_time==0) // If it is the first time the function is called or it is the start of a new bar. This could be after the open time (aka in the middle) of a bar.
      {
        D1_bar_time=D1_current_bar_open_time;
        D1_open_price=D1_current_bar_open_price;
        if(wait_for_next_bar) return false; // after loading the EA for the first time, if the user wants to wait for the next bar for the bar to be considered new
        else 
          {
            if(print_time_info) Print("new day (1)");
            return true;
          }
      }
    else if(D1_current_bar_open_time>D1_bar_time && compare_doubles(D1_open_price,D1_current_bar_open_price,digits)!=0) // if the opening time and price of this bar is different than the opening time and price of the previous one
      {
        D1_bar_time=D1_current_bar_open_time; // assuring the true value only gets returned for 1 tick and not the very next ones
        //Print("D1_bar_time: ",int(D1_bar_time/3600));
        D1_open_price=D1_current_bar_open_price; // assuring the true value only gets returned for 1 tick and not the very next ones
        if(print_time_info) Print("new day (2)");
        return true;
      }
    else if(TimeCurrent()-D1_bar_time>86400) // sometimes a new bar is not recognized, so this will make sure it is
      {
        D1_bar_time=D1_current_bar_open_time;
        //Print("D1_bar_time: ",int(D1_bar_time/3600));
        D1_open_price=D1_current_bar_open_price;
        if(print_time_info) Print("new day (3)");
        return true; 
      }  
    else return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_new_custom_D1_bar(string instrument,datetime current_time) // this function gets called once an hour (on the hour)
  {  
    static datetime D1_bar_time=0;
    static double   D1_open_price=0;
    static datetime D1_current_bar_close_time=0;
    datetime        D1_current_bar_open_time;
    is_new_D1_bar=is_new_D1_bar(instrument,false);
    if(is_new_D1_bar && TimeDayOfWeek(current_time)==0) D1_current_bar_close_time=current_time;
    if(TimeDayOfWeek(current_time)==0 && gmt_hour_offset<0) 
      {
        datetime day_start=iTime(NULL,PERIOD_D1,0);
        int market_start_hour=get_sundays_start_hour(instrument,day_start,4);
        D1_current_bar_open_time=day_start+(market_start_hour*3600);
      }
    else
        D1_current_bar_open_time=iTime(NULL,PERIOD_D1,0)+(gmt_hour_offset*3600);
    double D1_current_bar_open_price=iOpen(NULL,PERIOD_M5,iBarShift(NULL,PERIOD_M5,D1_current_bar_open_time,false));
    int    digits=(int)MarketInfo(instrument,MODE_DIGITS);
    if(D1_bar_time<=0) // If it is the first time the function is called or it is the start of a new bar. This could be after the open time (aka in the middle) of a bar.
      {
        D1_bar_time=D1_current_bar_open_time;
        D1_open_price=D1_current_bar_open_price;
        if(days_open_time<=0) set_custom_D1_open_time(instrument,0); // get the D1 bar's open time (based on the current time) // this will get a value for the weeks_open_time global variable
        if(gmt_hour_offset<0) D1_current_bar_close_time=round_down_to_hours(days_open_time)+86400;
        //Print("hours_open_time: ",TimeToStr(hours_open_time)," days_open_time: ",TimeToStr(days_open_time));
        if(TimeHour(hours_open_time)==TimeHour(days_open_time)) // using the TimeHour function to ensure that the hours are only compared (because, sometimes, the minutes might be slightly off)
          {
            if(DayOfWeek()==5 && TimeHour(current_time)!=0) print_and_email("Warning","new custom day (1) on a FRIDAY",!print_time_info);
            else if(print_time_info) Print("new custom day (1)");
            return true;
          }
        else 
          {
            return false; 
          }
      }
    if(gmt_hour_offset<0 && current_time>=D1_current_bar_close_time && TimeHour(current_time)==24+gmt_hour_offset)
      {
        set_custom_D1_open_time(instrument,0); // get the D1 bar's open time global variable (based on the current time\hour)  
        D1_bar_time=D1_current_bar_open_time;
        D1_open_price=D1_current_bar_open_price; // assuring the true value only gets returned for 1 tick and not the very next ones
        D1_current_bar_close_time=round_down_to_hours(days_open_time)+86400;
        //Print("D1_current_bar_close_time set to: ",D1_current_bar_close_time);
        if(DayOfWeek()==5 && TimeHour(current_time)!=0) print_and_email("Warning","new custom day (2) on a FRIDAY (when gmt_hour_offset<0)",!print_time_info);
        else if(print_time_info) Print("new custom day (2) (when gmt_hour_offset<0)");
        return true;
      }
    else if(gmt_hour_offset==0 && D1_current_bar_open_time>D1_bar_time && compare_doubles(D1_open_price,D1_current_bar_open_price,digits)!=0) // if the opening time and price of this bar is different than the opening time and price of the previous one
      {
        D1_bar_time=D1_current_bar_open_time; // assuring the true value only gets returned for 1 tick and not the very next ones
        D1_open_price=D1_current_bar_open_price; // assuring the true value only gets returned for 1 tick and not the very next ones
        set_custom_D1_open_time(instrument,0); // get the D1 bar's open time global variable (based on the current time\hour)
        if(DayOfWeek()==5 && TimeHour(current_time)!=0) print_and_email("Warning","new custom day (3) on a FRIDAY (when gmt_hour_offset==0)",!print_time_info);
        else if(print_time_info) Print("new custom day (3) (when gmt_hour_offset==0)");
        return true;
      }
    else return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_new_custom_W1_bar(string instrument,bool wait_for_next_bar) // this function gets called once a day
  {
    static datetime W1_bar_time=0;
    static double   W1_open_price=0;
    datetime        W1_current_bar_open_time=0;
    double          W1_current_bar_open_price=0;
    int             digits=(int)MarketInfo(instrument,MODE_DIGITS);
    //datetime week_start_open_time=iTime(NULL,PERIOD_W1,0)+(gmt_offset*3600); // The iTime of the week bar gives you the time that the week is 0:00 on the chart so I shifted the time to start when the markets actually start.
    int day=DayOfWeek();
    if(day>1 && day<7) return false; // If the day is tuesday through saturday, return false. (Intentionally leaving out Sunday and Monday which could actually be the start of a new week.)
    bool got_monday=false;
    for(int i=0;i<7;i++) // get the week start information only
      {
        if(got_monday) break;
        else
          {
            datetime days_start_time=iTime(NULL,PERIOD_D1,i);
            int i_day=TimeDayOfWeek(days_start_time);
            if(i_day==0) // if it is Sunday
              {
                int market_open_hour=get_sundays_start_hour(instrument,days_start_time,5);
                W1_current_bar_open_time=days_start_time+(market_open_hour*3600);
                int _weeks_start_bar=iBarShift(NULL,PERIOD_M5,W1_current_bar_open_time,false);
                W1_current_bar_open_price=iOpen(NULL,PERIOD_M5,_weeks_start_bar);
                //Print("W1_current_bar_open_time: ",TimeToStr(W1_current_bar_open_time));
                //Print("W1_current_bar_open_price: ",DoubleToStr(W1_current_bar_open_price));
                got_monday=true;
              } 
            else if(i_day==1) // if it is Monday
              {
                W1_current_bar_open_time=days_start_time+(gmt_hour_offset*3600);
                int _weeks_start_bar=iBarShift(NULL,PERIOD_M5,W1_current_bar_open_time,false);
                W1_current_bar_open_price=iOpen(NULL,PERIOD_M5,_weeks_start_bar);
                got_monday=true;
              }
          }
      }  
    if(W1_bar_time<=0) // If it is the first time the function is called or it is the start of a new bar. This could be after the open time (aka in the middle) of a bar.
      {
        //Print("first part");
        W1_bar_time=W1_current_bar_open_time;
        W1_open_price=W1_current_bar_open_price;
        set_custom_W1_times(instrument,include_last_week,H1s_to_roll,gmt_hour_offset); // this will get a value for the weeks_open_time global variable 
        if(TimeDay(days_open_time)==TimeDay(weeks_open_time) && TimeHour(days_open_time)==TimeHour(weeks_open_time)) // using the TimeDay function to ensure that the day of the months are only compared (because, sometimes, the minutes might be slightly off)
          {
            if(print_time_info) Print("new custom week (1)");
            return true;
          }  
        if(wait_for_next_bar) return false;
        else 
          {
            if(print_time_info) Print("new custom week (2)");
            return true; 
          }  
      }
    // TODO: work on the commented out code below
    /*else if(gmt_hour_offset<0 && DayOfWeek()==0) // if the opening time and price of this bar is different than the opening time and price of the previous one
      {
        //Print("second part");
        W1_bar_time=W1_current_bar_open_time; // assuring the true value only gets returned for 1 tick and not the very next ones
        W1_open_price=W1_current_bar_open_price; // assuring the true value only gets returned for 1 tick and not the very next ones
        weeks_open_time=-1;
        last_weeks_end_time=-1; // for when the user has the include_last_week parameter set to true
        set_custom_W1_times(instrument,include_last_week,H1s_to_roll,gmt_hour_offset); // this will get a value for the weeks_open_time global variable

        Print("new week 3");
        return true; // TODO: test that this returns true only once a week
      }*/
    else if(/*gmt_hour_offset==0 &&*/ W1_current_bar_open_time>W1_bar_time && compare_doubles(W1_open_price,W1_current_bar_open_price,digits)!=0) // if the opening time and price of this bar is different than the opening time and price of the previous one
      {
        //Print("second part");
        W1_bar_time=W1_current_bar_open_time; // assuring the true value only gets returned for 1 tick and not the very next ones
        W1_open_price=W1_current_bar_open_price; // assuring the true value only gets returned for 1 tick and not the very next ones
        weeks_open_time=-1;
        last_weeks_end_time=-1; // for when the user has the include_last_week parameter set to true
        set_custom_W1_times(instrument,include_last_week,H1s_to_roll,gmt_hour_offset); // this will get a value for the weeks_open_time global variable
        //Print("new week 4");
        //Print(TimeDay(days_open_time));
        //Print(TimeDay(weeks_open_time));
        //Print(TimeHour(days_open_time));
        //Print(TimeHour(weeks_open_time));
        if(TimeDay(days_open_time)==TimeDay(weeks_open_time) && TimeHour(days_open_time)==TimeHour(weeks_open_time)) // using the TimeDay function to ensure that the day of the months are only compared (because, sometimes, the minutes might be slightly off)
          {
            if(print_time_info) Print("new custom week (3)");
            return true;
          }
        else return false;
      }
    else return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void set_custom_D1_open_time(string instrument,int shift) // call this function if you want to know the D1 bar's open time only when checking for this at a random time
  {
    datetime  server_days_open_time=iTime(instrument,PERIOD_D1,shift); // TODO: test round_down_to_days on this
    int       gmt_seconds_offset=gmt_hour_offset*3600;
    if(gmt_seconds_offset<0) 
      {
        datetime temp_days_open_time=server_days_open_time+86400+gmt_seconds_offset; // the time at the end of the day minus the seconds of the GMT offset
        if(TimeCurrent()>=temp_days_open_time) days_open_time=temp_days_open_time;
        else 
          {
            if(TimeDayOfWeek(server_days_open_time)==0) // If it is Sunday
              {
                int market_open_hour=get_sundays_start_hour(instrument,server_days_open_time,6);
                days_open_time=server_days_open_time+(market_open_hour*3600);
                if(print_time_info) Print("server days open time: ",TimeToStr(server_days_open_time));
              }
            else
              {
                days_open_time=server_days_open_time+gmt_seconds_offset;  
              }
          }  
      }
    else if(gmt_seconds_offset>0) 
      {
        datetime temp_days_open_time=server_days_open_time+gmt_seconds_offset;
        if(TimeCurrent()>=temp_days_open_time) days_open_time=(temp_days_open_time);
        else days_open_time=temp_days_open_time-86400; // return the time of the D1 bar 24 hours prior
        // TODO: if you every have a positive gmt_offset_hour, you may want to have similar code here as you have when it is negative
      }
    else 
      {
        days_open_time=server_days_open_time; // when gmt_seconds_offset==0
      }  
    //Print("days_open_time set to: ",TimeToString(days_open_time));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int get_sundays_start_hour(string instrument,datetime sundays_bar_time,int coming_from)
  {
    static int      last_hour;
    static datetime last_date;
    if(last_hour==NULL || sundays_bar_time!=last_date)
      {
        int bar=-1;
        bool found_hour=false;
        for(int hr=0;hr<24;hr++) // 24 iterations (it must be 24 or else the loop will never pick up the 23rd hour of the day)
          {
            if(found_hour==false)
              {
                bar=iBarShift(instrument,PERIOD_H1,sundays_bar_time+(hr*3600),true);
                //Print(bar);
                if(bar!=-1) 
                  {
                    found_hour=true;
                    last_hour=hr;
                    last_date=sundays_bar_time;
                  }
              }
          }
      }
    return last_hour;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void set_custom_W1_times(string instrument,bool _include_last_week,double _H1s_to_roll,int gmt_offset)
  {
    int gmt_offset_seconds=gmt_offset*3600; // this is usually negative because thew passed in argument (gmt_offset) is usually negative.
    // TODO: the below code may not be compatible if the gmt_offset is positive
    if(_include_last_week)
      {
        //if(DayOfWeek()<=1 || (DayOfWeek()*24)<_H1s_to_roll) // if it is Sunday or Monday or the H1s_to_roll exceeds the max possible hours since the start of the week
          //{
            bool got_monday_and_friday=false;
            bool got_monday=false;
            for(int i=0;i<7;i++)
              {
                if(got_monday_and_friday) break;
                else
                  {
                    datetime server_days_start_time=iTime(instrument,PERIOD_D1,i);
                    int i_day=TimeDayOfWeek(server_days_start_time);
                    if(i_day==0) // if it is Sunday
                      {
                        int market_start_hour=get_sundays_start_hour(instrument,server_days_start_time,2);
                        server_days_start_time=server_days_start_time+(market_start_hour*3600);
                        weeks_open_time=server_days_start_time; // there is no need to add a gmt offset because if the broker's server says it is Sunday, the D1 start time is indeed the beginning of the week
                        got_monday=true; // got_monday does indeed=true because, in reality the broker's Sunday server time is the same as a Monday                            
                      }                     
                    else if(i_day==1 && got_monday==false) // if it is Monday
                      {
                        weeks_open_time=server_days_start_time+(gmt_offset_seconds);
                        //Print("monday: ",TimeToString(weeks_open_time));
                        got_monday=true;
                      }
                    else if(i_day==5) // if it is Friday
                      {
                        last_weeks_end_time=server_days_start_time+(86400-1)+(gmt_offset_seconds); // FYI, there are 86,400 seconds in 24 hours. And subtract 1 second to ensure you are still within that day.
                        if(got_monday) got_monday_and_friday=true; // to make sure you got_monday of this week before you got_friday of last week
                      }
                  }
              }
          //}
      }
    else if(_include_last_week==false) // if the user's setting is to NOT include last week, the EA should do less work because it doesn't need last week's values
      {
        bool got_monday=false;
        for(int i=0;i<7;i++) // get the week start information only
          {
            if(got_monday) break;
            else
              {
                datetime days_start_time=iTime(instrument,PERIOD_D1,i);
                int i_day=TimeDayOfWeek(days_start_time);
                if(i_day==0) // Finding the Sunday first takes the priority over finding the Monday first in this particular iteration.  IF there even is a Sunday, because that will be the true start of the week
                  {
                    int market_start_hour=get_sundays_start_hour(instrument,days_start_time,3);
                    weeks_open_time=days_start_time+(market_start_hour*3600); // there is no need to add a gmt offset because if the broker's server says it is Sunday, the D1 start time is indeed the beginning of the week
                    got_monday=true;
                  } 
                else if(i_day==1) // if it is Monday
                  {
                    weeks_open_time=days_start_time+(gmt_offset_seconds);
                    got_monday=true;
                  }
              }
          }
      }
    //Print("weeks_open_time set to: ",TimeToString(weeks_open_time));
    //if(_include_last_week>0) Print("last_weeks_end_time set to: ",TimeToString(last_weeks_end_time));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool days_move_too_big(string instrument)
  {
    int digits=(int)MarketInfo(instrument,MODE_DIGITS);
    double days_range=iHigh(instrument,PERIOD_D1,0)-iLow(instrument,PERIOD_D1,0);
    if(compare_doubles(days_range,ADR_pts*move_too_big_multiplier,digits)==1) 
      return true;
    else 
      return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double ADR_pts_raw_calculation(string instrument,double low_outlier,double high_outlier,int _num_ADR_months)
  {
    double adr_pts;
    // determine how many saturday and sundays occured in the last 3 months
    int three_mnth_sat_sun_count=0;
    int three_mnth_num_days=3*22; // There are about 22 business days a month.
    int bars_on_chart=iBars(instrument,PERIOD_D1);

    // 1) count the number of Sundays in the past 6 months
    for(int i=three_mnth_num_days;i>0;i--) 
      {
        int day=TimeDayOfWeek(iTime(instrument,PERIOD_D1,i));
        if(day==0 || day==6) // count Saturdays and Sundays
          {
           three_mnth_sat_sun_count++;
          }
      }

    // 2) determine the number of D1 bars you should look back to get the _num_ADR_months requested
    double avg_sat_sun_per_day=three_mnth_sat_sun_count/three_mnth_num_days;
    int three_mnth_adjusted_num_days=(int)((avg_sat_sun_per_day*three_mnth_num_days)+three_mnth_num_days); // accurately estimate how many D1 bars you would have to go back to get the desired number of days to look back
    if(three_mnth_adjusted_num_days+1>bars_on_chart) 
      {
        print_and_email("Error","ADR_pts_raw_calculation: There are not enough D1 bars on the "+instrument+" chart to calculate ADR. (1)");
        Sleep(1000);
        ExpertRemove();
      }

    // 3) get the three month ADR average/the baseline that will be used to compare each day
    int three_mnth_non_sunday_count=0;
    double three_mnth_non_sunday_ADR_sum=0;
    for(int i=three_mnth_adjusted_num_days;i>0;i--) // get the raw ADR (outliers are included but not Sunday's outliers) for the approximate past 6 months
      {
        int day=TimeDayOfWeek(iTime(instrument,PERIOD_D1,i));
        if(day!=0 && day!=6) // if the day of week is not Saturday or Sunday
          {
           double HOD=iHigh(instrument,PERIOD_D1,i);
           double LOD=iLow(instrument,PERIOD_D1,i);
           three_mnth_non_sunday_ADR_sum+=HOD-LOD;
           three_mnth_non_sunday_count++;
          }
      }
    int digits=(int)MarketInfo(instrument,MODE_DIGITS);
    double three_mnth_ADR_avg=NormalizeDouble(three_mnth_non_sunday_ADR_sum/three_mnth_non_sunday_count,digits); // the first time getting the ADR average

    // 4) compare each day for the past 3 months to the three month ADR average but don't count the outliers
    three_mnth_non_sunday_ADR_sum=0;
    three_mnth_non_sunday_count=0;
    for(int i=three_mnth_adjusted_num_days;i>0;i--) // refine the ADR (outliers and Sundays are NOT included) for the approximate past 6 months
      {
        int day=TimeDayOfWeek(iTime(instrument,PERIOD_D1,i));
        if(day!=0 && day!=6) // if the day of week is not Sunday
          {
            double HOD=iHigh(instrument,PERIOD_D1,i);
            double LOD=iLow(instrument,PERIOD_D1,i);
            double days_range=HOD-LOD;
            double ADR_ratio=NormalizeDouble(days_range/three_mnth_ADR_avg,2); // ratio for comparing the current iteration with the 6 month average
            if(compare_doubles(ADR_ratio,low_outlier,2)==1 && compare_doubles(ADR_ratio,high_outlier,2)==-1) // filtering out outliers // TODO: you may not have to use compare_doubles()
              {
                three_mnth_non_sunday_ADR_sum+=days_range;
                three_mnth_non_sunday_count++;
              }
          }
      }
    three_mnth_ADR_avg=NormalizeDouble(three_mnth_non_sunday_ADR_sum/three_mnth_non_sunday_count,digits); // the second time getting an ADR average but this time it is MORE REFINED

    // 5) compare each day for the past user-inputed-months to the three month ADR average but don't count the outliers
    double x_mnth_non_sunday_ADR_sum=0;
    int x_mnth_non_sunday_count=0;
    int x_mnth_num_days=_num_ADR_months*22; // There are about 22 business days a month.
    int x_mnth_adjusted_num_days=(int)((avg_sat_sun_per_day*x_mnth_num_days)+x_mnth_num_days); // accurately estimate how many D1 bars you would have to go back to get the desired number of days to look back
    if(x_mnth_adjusted_num_days+1>bars_on_chart) 
      {
        print_and_email("Error","ADR_pts_raw_calculation: There are not enough D1 bars on the "+instrument+" chart to calculate ADR. (2)");
        Sleep(1000);
        ExpertRemove();
      }
    for(int i=x_mnth_adjusted_num_days;i>0;i--) // find the counts of all days that are significantly below or above ADR
      {
        int day=TimeDayOfWeek(iTime(instrument,PERIOD_D1,i));
        if(day!=0 && day!=6) // if the day of week is not Sunday
          {
            double HOD=iHigh(instrument,PERIOD_D1,i);
            double LOD=iLow(instrument,PERIOD_D1,i);
            double days_range=HOD-LOD;
            double ADR_ratio=NormalizeDouble(days_range/three_mnth_ADR_avg,2); // ratio for comparing the current iteration with the 6 month average
            if(compare_doubles(ADR_ratio,low_outlier,2)==1 && compare_doubles(ADR_ratio,high_outlier,2)==-1) // filtering out outliers // you may not have to use compare_doubles()
              {
                x_mnth_non_sunday_ADR_sum+=days_range;
                x_mnth_non_sunday_count++;
              }
          }
      }
    adr_pts=NormalizeDouble(x_mnth_non_sunday_ADR_sum/x_mnth_non_sunday_count,digits);
    //Print("ADR_calculation returned: ",DoubleToStr(adr_pts,digits));
    //Print("ADR_calculation adr_pts: ",DoubleToStr(adr_pts));
    return adr_pts;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double get_ADR_pts_raw(string instrument,double hours_to_roll,double low_outlier,double high_outlier,int _num_ADR_months) // get the Average Daily Range
  {
    static double   _adr_pts=0;
    static datetime date_last_modified=-1;
    datetime        date=iTime(instrument,PERIOD_D1,0);
    if(date!=date_last_modified || _adr_pts==0)
      {
        if(low_outlier>high_outlier || _num_ADR_months<=0 || _num_ADR_months==NULL || MathMod(hours_to_roll,.25)!=0)
          {
            print_and_email("Error","get_raw_ADR_pts: The user inputed the wrong outlier variables or a H1s_to_roll number that is not divisible by .25. It is not possible to calculate ADR.");
            return -1;
          }
        else
          {
            //Print("get_raw_ADR_pts: ADR_calculation will be run");
            double calculated_adr_pts=ADR_pts_raw_calculation(instrument,low_outlier,high_outlier,_num_ADR_months);
            _adr_pts=calculated_adr_pts; // make the function remember the calculation the next time it is called
            //Print("get_raw_ADR_pts 1 returns:",DoubleToStr(_adr_pts));
            date_last_modified=date;
            return _adr_pts;
          }
        //Print("get_raw_ADR_pts 2 returns:",DoubleToStr(_adr_pts));
      }
    return _adr_pts; // if it is not the first time the function is called it is the middle of a bar, return the static adr
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void set_changed_ADR_pts(double hours_to_roll,double low_outlier,double high_outlier,double change_by_percent,string instrument,double _ADR_pts_raw)
  {
    string   current_chart=Symbol();
    double   bid_price=MarketInfo(current_chart,MODE_BID);
    string   ADR_pts_object=current_chart+"_ADR_pts";
    if(display_chart_objects && ObjectFind(current_chart+"_ADR_pts")<0 && instrument==current_chart) 
      {
        ObjectCreate(ADR_pts_object,OBJ_TEXT,0,TimeCurrent(),bid_price);
        ObjectSetText(ADR_pts_object,"0",15,NULL,clrWhite);
      }
    if(_ADR_pts_raw>0)
      {
        if(use_fixed_ADR && fixed_ADR_pips>0)
          {
            double point=MarketInfo(instrument,MODE_POINT);
            ADR_pts=fixed_ADR_pips*point*point_multiplier;
          }
        else
          {
            double current_ADR_pts=ADR_pts;
            int digits=(int)MarketInfo(instrument,MODE_DIGITS);
            if(change_by_percent==0 || change_by_percent==NULL)
              {
                ADR_pts=NormalizeDouble(_ADR_pts_raw,digits);
                if(ADR_pts!=current_ADR_pts) print_and_email("Info","set_changed_ADR_pts: A raw ADR of "+DoubleToString(_ADR_pts_raw,digits)+" for "+instrument+" was generated.");
              }
            else
              {
                ADR_pts=NormalizeDouble(((_ADR_pts_raw*change_by_percent)+_ADR_pts_raw),digits); // include the ability to increase\decrease the ADR by a certain percentage where the input is a global variable
                if(ADR_pts!=current_ADR_pts) print_and_email("Info","set_changed_ADR_pts: A raw ADR of "+DoubleToString(_ADR_pts_raw,digits)+" for "+instrument+" was generated. As requested by the user, it has been changed to "+DoubleToString(ADR_pts,digits));
              }
          }
        if(instrument==current_chart)
          {
            ObjectSetText(ADR_pts_object,DoubleToString(ADR_pts*100,3),0);
            ObjectMove(ADR_pts_object,0,TimeCurrent(),bid_price+ADR_pts/4);        
          }
      }
    else print_and_email("Error","set_changed_ADR_pts: An ADR_pts_raw of 0 or was passed into this function for "+instrument+".");
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+  
bool set_moves_start_bar(string instrument,double _H1s_to_roll,int gmt_offset,double _max_weekend_gap_percent,bool _include_last_week=true) // TODO: include current_time as a parameter?
  {
    int         _moves_start_bar=int(_H1s_to_roll*12/*-1*/); // any double divisible by .5 will always be an integer when multiplied by an even number like 12 so it is okay to convert it into an int
    string      current_chart=Symbol();
    string      move_start_text=current_chart+"_Move_Start";
    int         digits=(int)MarketInfo(instrument,MODE_DIGITS); 
    static bool alert_flag=false;
    if(DayOfWeek()==6) // if the broker's server time is Saturday
      {
        // reset all static and global variables to the default values
        weeks_open_time=-1;
        days_open_time=-1;
        last_weeks_end_time=-1;
      }
    else
      {
      /*if(uptrend || downtrend)
        {
          datetime pivot_time=-1;
          if(uptrend) pivot_time=LOP_time;
          else if(downtrend) pivot_time=HOP_time;
          moves_start_bar=iBarShift(instrument,PERIOD_M5,pivot_time,false);
        }*/
      //else
        //{
          // Remember that the weeks_open_time is a global variable that is reset to -1 when is_new_custom_W1_bar function returns true.
          if(include_previous_day && (weeks_open_time==-1 /*|| (day==1 && is_new_custom_W1_bar)*/))
            {
              set_custom_W1_times(instrument,_include_last_week,_H1s_to_roll,gmt_offset);
              //alert_flag=false;
            } 
          // Remember that the days_open_time is a global variable that should be set to -1 every end of day.
          else if(!include_previous_day && (days_open_time==-1))
            {
              set_custom_D1_open_time(instrument,0); // get the D1 bar's open time (based on the current time)
              if(display_chart_objects && ObjectFind(move_start_text)<0) 
                {
                  int days_start_bar=iBarShift(instrument,PERIOD_M5,days_open_time,false);
                  double days_open_price=iOpen(instrument,PERIOD_M5,days_start_bar);
                  ObjectCreate(move_start_text,OBJ_VLINE,0,days_open_time,days_open_price); // it only gets set to these anchors for 1 M5 bar, so it is okay if it is wrong the first bar.
                  ObjectSet(move_start_text,OBJPROP_COLOR,clrWhite);
                }
            }
          if(include_previous_day)
            {
              int weeks_start_bar=iBarShift(instrument,PERIOD_M5,weeks_open_time,false);
              
              if(display_chart_objects && ObjectFind(move_start_text)<0) 
                {
                  double weeks_open_price=iOpen(instrument,PERIOD_M5,weeks_start_bar);
                  ObjectCreate(move_start_text,OBJ_VLINE,0,weeks_open_time,weeks_open_price); // it only gets set to these anchors for 1 M5 bar, so it is okay if it is wrong the first bar.
                  ObjectSet(move_start_text,OBJPROP_COLOR,clrWhite);
                }
              if(_moves_start_bar<=weeks_start_bar) moves_start_bar=_moves_start_bar; 
              else if(_include_last_week)
                {
                  double weeks_open_price=iOpen(instrument,PERIOD_M5,weeks_start_bar);
                  double last_weeks_close_price=iClose(instrument,PERIOD_M5,iBarShift(instrument,PERIOD_M5,last_weeks_end_time,false));
                  double weekend_gap_points=MathAbs(last_weeks_close_price-weeks_open_price);
                  double max_weekend_gap_points=NormalizeDouble(((ADR_pts*change_ADR_percent)+ADR_pts)*_max_weekend_gap_percent,digits); // calculated based off of raw ADR (not the user's modified ADR)
                  if(weekend_gap_points>max_weekend_gap_points) // TODO: use compare_doubles()?
                    {
                      moves_start_bar=weeks_start_bar;
                      if(alert_flag==false)
                        {
                          Print("This weekend's weekend_gap_points based on the raw ADR (",DoubleToString(weekend_gap_points),") is > the user's max_weekend_gap_points (",DoubleToString(max_weekend_gap_points),") setting.");
                          alert_flag=true;
                        }
                    }
                  else moves_start_bar=_moves_start_bar;
                }
              else moves_start_bar=weeks_start_bar;   
            }
          else if(!include_previous_day)
            {
              int days_start_bar=iBarShift(instrument,PERIOD_M5,days_open_time,false);
              if(display_chart_objects && ObjectFind(move_start_text)<0) 
                {
                  double days_open_price=iOpen(instrument,PERIOD_M5,days_start_bar);
                  ObjectCreate(move_start_text,OBJ_VLINE,0,days_open_time,days_open_price); // it only gets set to these anchors for 1 M5 bar, so it is okay if it is wrong the first bar.
                  ObjectSet(move_start_text,OBJPROP_COLOR,clrWhite);
                }
              if(_moves_start_bar<=days_start_bar) moves_start_bar=_moves_start_bar;
              else moves_start_bar=days_start_bar;  
            }
        //}
        ObjectSet(move_start_text,OBJPROP_TIME1,iTime(current_chart,PERIOD_M5,moves_start_bar));
        ObjectSet(move_start_text,OBJPROP_PRICE1,iOpen(current_chart,PERIOD_M5,moves_start_bar));      
      }
    return true;
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
        int lowest_bar;
        if(moves_start_bar==0) lowest_bar=0;
        else lowest_bar=iLowest(instrument,PERIOD_M5,MODE_LOW,moves_start_bar,0);
        double pivot_price=iLow(instrument,PERIOD_M5,lowest_bar); // get the price of the bar that has the lowest price for the determined period
        //Print("The buying mode lowest_bar is: ",DoubleToString(lowest_bar));
        //Print("The buying mode pivot_price is: ",DoubleToString(pivot_price));
        //Print("periods_pivot_price(): Bid: ",DoubleToString(Bid));
        //Print("periods_pivot_price(): Bid-periods_pivot_price: ",DoubleToString(Bid-pivot_price));
        //Print("periods_pivot_price(): ADR_pts: ",DoubleToString(ADR_pts));
        return pivot_price;
      }
    else if(mode==SELLING_MODE)
      {
        int highest_bar;
        if(moves_start_bar==0) highest_bar=0;
        else highest_bar=iHighest(instrument,PERIOD_M5,MODE_HIGH,moves_start_bar,0);
        double pivot_price=iHigh(instrument,PERIOD_M5,highest_bar); // get the price of the bar that has the highest price for the determined period
        //Print("The selling mode highest_bar is: ",DoubleToString(highest_bar));
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
int ranges_pivot_bar(ENUM_DIRECTIONAL_MODE mode,string instrument)
  {
    if(mode==BUYING_MODE)
      { 
        int lowest_bar;
        if(moves_start_bar==0) 
          lowest_bar=0;
        else 
          lowest_bar=iLowest(instrument,PERIOD_M5,MODE_LOW,moves_start_bar,0);
        return lowest_bar;
      }
    else if(mode==SELLING_MODE)
      {
        int highest_bar;
        if(moves_start_bar==0) 
          highest_bar=0;
        else 
          highest_bar=iHighest(instrument,PERIOD_M5,MODE_HIGH,moves_start_bar,0);
        return highest_bar;
      }
    else 
      return -1;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double range_pts_calculation(int cmd,string instrument, int coming_from)
  {
    int ranges_pivot_bar;  
    if(cmd==OP_BUY)
      {
        double HOP;
        HOP=periods_pivot_price(SELLING_MODE,instrument); // get the pivot price since the move's start bar
        ranges_pivot_bar=ranges_pivot_bar(SELLING_MODE,instrument); // get the range's pivot bar since the move's start bar
        HOP_time=iTime(instrument,PERIOD_M5,ranges_pivot_bar);
        /*if(compare_doubles(HOP_price,HOP,Digits)!=0)
          {
            Print("range_pts_calculation: HOP_price changed to: ",DoubleToString(HOP,5));
            Print("range_pts_calculation: HOP_time changed to: ",TimeToString(HOP_time));       
          }*/
        HOP_price=HOP;
        //Print("HOP was recalculated coming from: ",coming_from);
        return(HOP_price-LOP_price);
      }
    if(cmd==OP_SELL)
      {
        double LOP;
        LOP=periods_pivot_price(BUYING_MODE,instrument); // get the pivot price since the move's start bar
        ranges_pivot_bar=ranges_pivot_bar(BUYING_MODE,instrument); // get the range;s pivot bar since the move's start bar
        LOP_time=iTime(instrument,PERIOD_M5,ranges_pivot_bar);
        /*if(compare_doubles(LOP_price,LOP,Digits)!=0)
          {
            Print("range_pts_calculation: LOP_price changed to: ",DoubleToString(LOP,5));
            Print("range_pts_calculation: LOP_time changed to: ",TimeToString(LOP_time));       
          }*/
        //Print("LOP was recalculated coming from: ",coming_from);
        LOP_price=LOP;
        return(HOP_price-LOP_price);
      }
    else return -1;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool uptrend_retracement_met_price(string instrument)
  {
    string current_chart=Symbol();
    bool   current_chart_matches=(current_chart==instrument);
    bool   _draw_visuals=(display_chart_objects && current_chart_matches);
    //if(uptrend==true && uptrend_order_was_last==true && LOP_price>0) Print("WARNING: uptrend_retracement_price did not analyze because uptrend_order_was_last==true");
    //if(uptrend==true && uptrend_order_was_last==false && LOP_price<=0) Print("WARNING: uptrend_retracement_price did not analyze because LOP_price<=0");
    if(uptrend==true && /*uptrend_order_was_last==false &&*/ LOP_price>0) // TODO: uptrend_trade_happened_last may be redundant because it is checked before this function even gets called
      {
        RefreshRates();
        static string last_instrument;
        static double retracement_pts=0;
        double        range_pts;
        int           digits=(int)MarketInfo(instrument,MODE_DIGITS);
        double        current_bid=MarketInfo(instrument,MODE_BID); // TODO: always make sure RefreshRates() was called before. In this case, it was called before running this function.
        if(last_instrument!=instrument || HOP_price<=0 /*|| LOP_price<=0*/) // if HOP is 0 or -1
          {
            //Print("HOP_price had to be generated");
            //Print("last_instrument: ",last_instrument," instrument: ",instrument);
            range_pts=range_pts_calculation(OP_BUY,instrument,2950);
            last_instrument=instrument;
            if(compare_doubles(range_pts,ADR_pts,digits)==-1 || HOP_price==-1 /*|| LOP_price==-1*/)
              {
                uptrend=false;
                ObjectSet(current_chart+"_HOP",OBJPROP_WIDTH,1);  
                return false; // this part is necessary in case periods_pivot_price ever returns 0
              }
            else retracement_pts=NormalizeDouble(range_pts*retracement_percent,digits);
          }
        if(current_bid>=HOP_price) // if the high of the range was surpassed // TODO: use compare_doubles()?
          {
            // since the top of the range was surpassed, you have to reset the HOP. You might as well take this opportunity to take the period into account.            
            HOP_price=current_bid;
            HOP_time=TimeCurrent();
            range_pts=HOP_price-LOP_price;
            retracement_pts=NormalizeDouble(range_pts*retracement_percent,digits);          
            if(_draw_visuals)
              {
                string hop_text=current_chart+"_retrace_HOP_up";
                string lop_text=current_chart+"_retrace_LOP_up";
                if(ObjectFind(hop_text)<0)
                  {
                    ObjectCreate(hop_text,OBJ_HLINE,0,TimeCurrent(),HOP_price);
                    ObjectSet(hop_text,OBJPROP_COLOR,clrYellow);
                    ObjectSet(hop_text,OBJPROP_STYLE,STYLE_DASH);
                    ObjectSet(hop_text,OBJPROP_WIDTH,1);
                  }
                if(ObjectFind(lop_text)<0)
                  {
                    ObjectCreate(lop_text,OBJ_HLINE,0,TimeCurrent(),HOP_price-retracement_pts);
                    ObjectSet(lop_text,OBJPROP_COLOR,clrYellow);
                    ObjectSet(lop_text,OBJPROP_STYLE,STYLE_DOT);
                    ObjectSet(lop_text,OBJPROP_WIDTH,1);
                  }
                ObjectSet(hop_text,OBJPROP_PRICE1,HOP_price);
                ObjectSet(hop_text,OBJPROP_WIDTH,1);
                ObjectSet(lop_text,OBJPROP_PRICE1,HOP_price-retracement_pts);  
                ObjectSet(lop_text,OBJPROP_WIDTH,1);
              }
            return false;
          } 
        else if(HOP_price-current_bid>=retracement_pts) // if the pip move meets or exceed the ADR_Pips in points, return the current bid. Note: this will return true over and over again // TODO: use compare_doubles()?
          {
            // since the bottom of the range was surpassed and a pending order would be created, this is a good opportunity to update the range in the period since you can't just leave it as the static value constantly
            range_pts=HOP_price-LOP_price;
            retracement_pts=NormalizeDouble(range_pts*retracement_percent,digits);
            //Print(TimeToString(HOP_time)," (HOP_time) should be > ",TimeToString(LOP_time)," (LOP_time)");
            if(HOP_price-current_bid>=retracement_pts && LOP_time<HOP_time) // TODO: use compare_doubles()?
              {
                //Print(TimeToString(HOP_time)," (HOP_time) should be > ",TimeToString(LOP_time)," (LOP_time)");
                if(_draw_visuals)
                  {
                    string hop_text=current_chart+"_retrace_HOP_up";
                    string lop_text=current_chart+"_retrace_LOP_up";
                    if(ObjectFind(hop_text)<0)
                      {
                        ObjectCreate(hop_text,OBJ_HLINE,0,TimeCurrent(),HOP_price);
                        ObjectSet(hop_text,OBJPROP_COLOR,clrYellow);
                        ObjectSet(hop_text,OBJPROP_STYLE,STYLE_DASH);
                        ObjectSet(hop_text,OBJPROP_WIDTH,1);
                      }
                    if(ObjectFind(lop_text)<0)
                      {
                        ObjectCreate(lop_text,OBJ_HLINE,0,TimeCurrent(),HOP_price-retracement_pts);
                        ObjectSet(lop_text,OBJPROP_COLOR,clrYellow);
                        ObjectSet(lop_text,OBJPROP_STYLE,STYLE_DOT);
                        ObjectSet(lop_text,OBJPROP_WIDTH,3);   
                      }
                    ObjectSet(hop_text,OBJPROP_PRICE1,HOP_price);
                    ObjectSet(hop_text,OBJPROP_WIDTH,1); 
                    ObjectSet(lop_text,OBJPROP_PRICE1,HOP_price-retracement_pts);
                    ObjectSet(lop_text,OBJPROP_WIDTH,3);
                  }
                if(too_big_move_percent>1)
                  {
                    bool too_big_move=compare_doubles(range_pts,NormalizeDouble(ADR_pts*too_big_move_percent,digits),digits)>=0;
                    if(too_big_move) 
                      {
                        //if(is_new_M5_bar) Print("too_big_move");
                        //Print("too_big_move");
                        reset_pivot_peak(instrument);
                        ObjectDelete(current_chart+"_retrace_HOP_up");
                        ObjectDelete(current_chart+"_retrace_HOP_down");
                        ObjectDelete(current_chart+"_retrace_LOP_up");
                        ObjectDelete(current_chart+"_retrace_LOP_down");
                        return false;
                      }                
                  }
                return true;  
              }
            else return false;
          }         
        else return false;
      }
    else 
      {
        if(is_new_M5_bar && uptrend==true && uptrend_order_was_last==false && (LOP_price<=0 || LOP_price==NULL)) Print("WARNING: uptrend_retracement_met_price: No trades will happen because LOP_price wasn't assigned a value.");
        if(uptrend==false && current_chart_matches)
          {
            ObjectDelete(current_chart+"_retrace_HOP_up");
            ObjectDelete(current_chart+"_retrace_LOP_up");     
          }
        return false;
      }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool downtrend_retracement_met_price(string instrument)
  {
    string current_chart=Symbol();
    bool   current_chart_matches=(current_chart==instrument);
    bool   _draw_visuals=(display_chart_objects && current_chart_matches);
    //if(downtrend==true && downtrend_order_was_last==true && HOP_price>0) Print("WARNING: downtrend_retracement_price did not analyze because downtrend_order_was_last==true");
    //if(downtrend==true && downtrend_order_was_last==false && HOP_price<=0) Print("WARNING: downtrend_retracement_price did not analyze because HOP_price<=0");
    if(downtrend==true && /*downtrend_order_was_last==false &&*/ HOP_price>0) // TODO: uptrend_trade_happened_last may be redundant because it is checked before this function even gets called
      {
        RefreshRates();
        static string last_instrument;
        static double retracement_pts=0;
        double range_pts;
        int digits=(int)MarketInfo(instrument,MODE_DIGITS);
        double current_bid=MarketInfo(instrument,MODE_BID); // TODO: always make sure RefreshRates() was called before. In this case, it was called before running this function.
        if(last_instrument!=instrument || LOP_price<=0 /*|| HOP_price<=0*/) // if LOP is 0 or -1
          {
            //Print("LOP_price had to be generated");
            //Print("last_instrument: ",last_instrument," instrument: ",instrument);
            range_pts=range_pts_calculation(OP_SELL,instrument,3080);
            last_instrument=instrument;
            if(compare_doubles(range_pts,ADR_pts,digits)==-1 || LOP_price==-1 /*|| HOP_price==-1*/)
              {
                downtrend=false;
                ObjectSet(current_chart+"_LOP",OBJPROP_WIDTH,1);   
                return false; // this part is necessary in case periods_pivot_price ever returns 0
              }
            else retracement_pts=NormalizeDouble(range_pts*retracement_percent,digits);
          }
        if(current_bid<=LOP_price) // if the low of the range was surpassed // TODO: use compare_doubles()?
          {
            // since the top of the range was surpassed, you have to reset the HOP. You might as well take this opportunity to take the period into account.
            LOP_price=current_bid;
            LOP_time=TimeCurrent();
            range_pts=HOP_price-LOP_price;
            //range_pts=range_pts_calculation(OP_SELL,instrument);
            retracement_pts=NormalizeDouble(range_pts*retracement_percent,digits);          
            if(_draw_visuals) // TODO: in a downtrend, only show the lines if the LOP
              {
                string hop_text=current_chart+"_retrace_HOP_down";
                string lop_text=current_chart+"_retrace_LOP_down";
                if(ObjectFind(lop_text)<0)
                  {
                    
                    ObjectCreate(lop_text,OBJ_HLINE,0,TimeCurrent(),LOP_price);
                    ObjectSet(lop_text,OBJPROP_COLOR,clrYellow);
                    ObjectSet(lop_text,OBJPROP_STYLE,STYLE_DASH);
                    ObjectSet(lop_text,OBJPROP_WIDTH,1);
                  }
                if(ObjectFind(hop_text)<0)
                  {
                    ObjectCreate(hop_text,OBJ_HLINE,0,TimeCurrent(),LOP_price+retracement_pts);
                    ObjectSet(hop_text,OBJPROP_COLOR,clrYellow);
                    ObjectSet(hop_text,OBJPROP_STYLE,STYLE_DOT);
                    ObjectSet(hop_text,OBJPROP_WIDTH,1);
                  }
                //Print("LOP_price: ",DoubleToStr(LOP_price));
                ObjectSet(lop_text,OBJPROP_PRICE1,LOP_price);
                ObjectSet(lop_text,OBJPROP_WIDTH,1);
                ObjectSet(hop_text,OBJPROP_PRICE1,LOP_price+retracement_pts);
                ObjectSet(hop_text,OBJPROP_WIDTH,1);
              }
            return false;
          } 
        else if(current_bid-LOP_price>=retracement_pts) // if the pip move meets or exceed the ADR_Pips in points, return the current bid. Note: this will return true over and over again // TODO: use compare_doubles()?
          {
            // since the bottom of the range was surpassed and a pending order would be created, this is a good opportunity to update the range in the period since you can't just leave it as the static value constantly
            range_pts=HOP_price-LOP_price;
            retracement_pts=NormalizeDouble(range_pts*retracement_percent,digits);
            //Print("triggered");
            //Print("current_bid-LOP_price>=retracement_pt ",current_bid-LOP_price>=retracement_pts);
            //Print("HOP_time<LOP_time ",HOP_time<LOP_time);  
            if(current_bid-LOP_price>=retracement_pts && HOP_time<LOP_time) // TODO: use compare_doubles()?
              {
                //Print(TimeToString(HOP_time)," (HOP_time) should be < ",TimeToString(LOP_time)," (LOP_time)");
                if(_draw_visuals)
                  {
                    string hop_text=current_chart+"_retrace_HOP_down";
                    string lop_text=current_chart+"_retrace_LOP_down";
                    if(ObjectFind(lop_text)<0)
                      {
                        ObjectCreate(lop_text,OBJ_HLINE,0,TimeCurrent(),LOP_price);
                        ObjectSet(lop_text,OBJPROP_COLOR,clrYellow);
                        ObjectSet(lop_text,OBJPROP_STYLE,STYLE_DASH);
                        ObjectSet(lop_text,OBJPROP_WIDTH,1);
                      }
                    if(ObjectFind(hop_text)<0)
                      {
                        ObjectCreate(hop_text,OBJ_HLINE,0,TimeCurrent(),LOP_price+retracement_pts);
                        ObjectSet(hop_text,OBJPROP_COLOR,clrYellow);
                        ObjectSet(hop_text,OBJPROP_STYLE,STYLE_DOT);
                        ObjectSet(hop_text,OBJPROP_WIDTH,3);
                      }
                    ObjectSet(lop_text,OBJPROP_PRICE1,LOP_price);
                    ObjectSet(lop_text,OBJPROP_WIDTH,1);
                    ObjectSet(hop_text,OBJPROP_PRICE1,LOP_price+retracement_pts);
                    ObjectSet(hop_text,OBJPROP_WIDTH,3);       
                  }
                if(too_big_move_percent>1)
                  {
                    bool too_big_move=compare_doubles(range_pts,NormalizeDouble(ADR_pts*too_big_move_percent,digits),digits)>=0;
                    if(too_big_move) 
                      {
                        //if(is_new_M5_bar) Print("too_big_move");
                        //Print("too_big_move");                        
                        //reset the LOP_price, HOP_price, and trends because the signal is no longer valid
                        reset_pivot_peak(instrument);
                        ObjectDelete(current_chart+"_retrace_HOP_up");
                        ObjectDelete(current_chart+"_retrace_HOP_down");
                        ObjectDelete(current_chart+"_retrace_LOP_up");
                        ObjectDelete(current_chart+"_retrace_LOP_down");
                        return false;
                      }                
                  }
                return true;  
              }
            else return false;
          }
        else return false;
      }
    else
      {
        if(is_new_M5_bar && downtrend==true && downtrend_order_was_last==false && (HOP_price<=0 || HOP_price==NULL)) Print("WARNING: downtrend_retracement_met_price: No trades will happen because HOP_price wasn't assigned a value.");
        if(downtrend==false && current_chart_matches)
          {
            ObjectDelete(current_chart+"_retrace_HOP_down");
            ObjectDelete(current_chart+"_retrace_LOP_down");
          }
        return false;
      }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool uptrend_ADR_threshold_met_price(string instrument,bool get_current_bid_instead=false)
  {
    double current_bid=MarketInfo(instrument,MODE_BID); // TODO: always make sure RefreshRates() was called before. In this case, it was called before running this function.
    string current_chart=Symbol();
    bool   current_chart_matches=(current_chart==instrument);
    string LOP_text=current_chart+"_LOP";
    string HOP_text=current_chart+"_HOP";
    int    digits=(int)MarketInfo(instrument,MODE_DIGITS);
    if(display_chart_objects && current_chart_matches)
      {
        if(ObjectFind(LOP_text)<0)
          {
            ObjectCreate(LOP_text,OBJ_HLINE,0,LOP_time,LOP_price);
            ObjectSet(LOP_text,OBJPROP_COLOR,clrWhite);
          }
        if(ObjectFind(HOP_text)<0)
          {
            ObjectCreate(HOP_text,OBJ_HLINE,0,LOP_time,LOP_price+ADR_pts);
            ObjectSet(HOP_text,OBJPROP_COLOR,clrWhite);
          }     
      } 
    if(current_bid<LOP_price) // if the low of the range was surpassed // TODO: use compare_doubles()?
      {
        // since the bottom of the range was surpassed, you have to reset the LOP. You might as well take this opportunity to take the period into account.
        range_pts_calculation(OP_SELL,instrument,3200); // evaluates the LOP_price and LOP_time
        uptrend=false;
        ObjectSet(HOP_text,OBJPROP_WIDTH,1);
        if(current_chart_matches)
          {
            ObjectSet(LOP_text,OBJPROP_PRICE1,LOP_price);
            ObjectSet(HOP_text,OBJPROP_PRICE1,LOP_price+ADR_pts);        
          }
        return false;
      } 
    else if(/*HOP_time>LOP_time &&*/ current_bid-LOP_price>=ADR_pts) // if the pip move meets or exceed the ADR_Pips in points, return the current bid. Note: this will return true over and over again // TODO: use compare_doubles()?
      {
        bool retracement_mode_on=retracement_percent>0;
        // since the top of the range was surpassed, this is a good opportunity to update the LOP since you can't just leave it as the static value constantly
        range_pts_calculation(OP_SELL,instrument,3225); // evaluates the LOP_price and LOP_time
        if(/*HOP_time>LOP_time &&*/ current_bid-LOP_price>=ADR_pts) // TODO: use compare_doubles()?
          {
            if(uptrend==false) // if it is the first time the uptrend ADR is triggered when the user wants to enter trades with a retracement_percent
              {
                // You need to reassign the HOP_price and HOP_time to what it is currently because the previous variable assignments can be off
                HOP_time=TimeCurrent();
                HOP_price=current_bid;
                uptrend=true;
                uptrend_time=TimeCurrent();
                downtrend=false;
                //Print("uptrend");
                ObjectSet(HOP_text,OBJPROP_WIDTH,4);
                ObjectSet(LOP_text,OBJPROP_WIDTH,1);
                // from now on, the uptrend_retracement_met_price function will handle the updating of the HOP_time and HOP_price since it runs when uptrend==true (which is assigned below)
              }
            else
              {
                range_pts_calculation(OP_BUY,instrument,3250); // evaluates the HOP_price and HOP_time
              }
            if(current_chart_matches)
              {
                ObjectSet(LOP_text,OBJPROP_PRICE1,LOP_price);
                ObjectSet(HOP_text,OBJPROP_PRICE1,LOP_price+ADR_pts);
              } 
            if(retracement_mode_on==false && uptrend_order_was_last) return false; // to prevent orders from entering immediately after one closes
            if(HOP_time>LOP_time) return true;
          }
        else return false;
      }
    /*else if(uptrend && current_bid<(HOP_price-(ADR_pts/2)))
      {
        uptrend=false; 
      }*/
    return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool downtrend_ADR_threshold_met_price(string instrument,bool get_current_bid_instead=false)
  {
    double current_bid=MarketInfo(instrument,MODE_BID); // TODO: always make sure RefreshRates() was called before. In this case, it was called before running this function.
    string current_chart=Symbol();
    bool   current_chart_matches=(current_chart==instrument);
    string LOP_text=current_chart+"_LOP";
    string HOP_text=current_chart+"_HOP";
    int    digits=(int)MarketInfo(instrument,MODE_DIGITS);
    if(display_chart_objects && current_chart_matches)
      {
        if(ObjectFind(HOP_text)<0)
          {
            ObjectCreate(HOP_text,OBJ_HLINE,0,HOP_time,HOP_price);
            ObjectSet(HOP_text,OBJPROP_COLOR,clrWhite);
          }
        if(ObjectFind(LOP_text)<0)
          {
            ObjectCreate(LOP_text,OBJ_HLINE,0,HOP_time,HOP_price-ADR_pts);
            ObjectSet(LOP_text,OBJPROP_COLOR,clrWhite);
          }
      }
    if(current_bid>HOP_price) // if the low of the range was surpassed // TODO: use compare_doubles()?
      {
        // since the top of the range was surpassed, you have to reset the LOP. You might as well take this opportunity to take the period into account.
        range_pts_calculation(OP_BUY,instrument,3300); // evaluates the HOP_price and HOP_time
        downtrend=false;
        ObjectSet(LOP_text,OBJPROP_WIDTH,1);
        if(current_chart_matches)
          {
            ObjectSet(HOP_text,OBJPROP_PRICE1,HOP_price);
            ObjectSet(LOP_text,OBJPROP_PRICE1,HOP_price-ADR_pts);
          }
        return false;
      } 
    else if(/*LOP_time>HOP_time &&*/ HOP_price-current_bid>=ADR_pts) // if the pip move meets or exceed the ADR_Pips in points, return the current bid. Note: this will return true over and over again // TODO: use compare_doubles()?
      {
        bool retracement_mode_on=retracement_percent>0;   
        // since the top of the range was surpassed, this is a good opportunity to update the LOP since you can't just leave it as the static value constantly
        range_pts_calculation(OP_BUY,instrument,3310); // evaluates the HOP_price and HOP_time
        if(/*LOP_time>HOP_time &&*/ HOP_price-current_bid>=ADR_pts) // TODO: use compare_doubles()?
          {
            if(downtrend==false) // if it is the first time the downtrend ADR is triggered when the user wants to enter trades with a retracement_percent
              {
                // You need to reassign the HOP_price and HOP_time to what it is currently because the previous variable assignments can be off
                LOP_time=TimeCurrent();
                LOP_price=current_bid;
                downtrend=true;
                uptrend=false;
                downtrend_time=TimeCurrent();
                //Print("downtrend");
                ObjectSet(HOP_text,OBJPROP_WIDTH,1);
                ObjectSet(LOP_text,OBJPROP_WIDTH,4);
                // from now on, the retracement_met_price function will handle the updating of the LOP_time and LOP_price since it runs when downtrend==true (which is assigned below)
              }
            else
              {
                range_pts_calculation(OP_SELL,instrument,3325); // evaluates the LOP_price and LOP_time
              }        
            if(current_chart_matches)
              {
                ObjectSet(HOP_text,OBJPROP_PRICE1,HOP_price);
                ObjectSet(LOP_text,OBJPROP_PRICE1,HOP_price-ADR_pts);
              }  
            if(retracement_percent==0 && downtrend_order_was_last) return false; // to prevent orders from entering immediately after one closes
            if(LOP_time>HOP_time) return true;
          }
        else return false;
      }
    /*else if(downtrend && current_bid>(LOP_price+(ADR_pts/2)))
      {
        downtrend=false;
      }*/    
    return false;
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
bool try_to_modify_order(int ticket,double sl_pts,int _retries=3,double tp_pts=-1,datetime expire=-1,double entryPrice=-1,color a_color=clrNONE,int sleep_milisec=1000) // TODO: should the defaults really be -1?
  {
    bool result=false;
    if(ticket>0)
      {
        for(int i=0;i<_retries;i++)
          {
            if(!IsConnected()) print_and_email("Error","The EA can't modify ticket "+IntegerToString(ticket)+" because there is no internet connection.");
            else if(!IsExpertEnabled()) print_and_email("Error","The EA can't modify ticket "+IntegerToString(ticket)+" because EAs are not enabled in the trading platform.");
            else if(IsTradeContextBusy()) print_and_email("Error","The EA can't modify ticket "+IntegerToString(ticket)+" because The trade context is busy.");
            else if(!IsTradeAllowed()) print_and_email("Error","The EA can't modify ticket "+IntegerToString(ticket)+" because the trade is not allowed while a thread for trading is occupied.");
            else result=modify_order(ticket,sl_pts,tp_pts,expire,entryPrice,a_color); // entryPrice could be -1 if there was no entryPrice sent to this function
            if(result) break;
            Sleep(sleep_milisec);
            // TODO: setup an email and SMS alert.
            print_and_email("Error",OrderSymbol()+" , "+WindowExpertName()+", An order was attempted to be modified but it did not succeed. Last Error: ("+IntegerToString(GetLastError(),0)+"), Retry: "+IntegerToString(i,0)+"/"+IntegerToString(retries));
            //Alert(OrderSymbol()," , ",WindowExpertName(),", An order was attempted to be modified but it did not succeed. Check the Journal tab of the Navigator window for errors.");
          }
      }
    else
      {   
        print_and_email("Error",OrderSymbol()+" , "+WindowExpertName()+", Modifying the order was not successfull. The ticket couldn't be selected.");
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
bool try_to_exit_order(int ticket,int max_slippage_pips,int _retries=3,color a_color=clrNONE,int sleep_milisec=1000)
  {
    bool result=false;
    for(int i=0;i<_retries;i++)
      {
        if(!IsConnected()) print_and_email("Error","The EA can't close ticket "+IntegerToString(ticket)+" because there is no internet connection.");
        else if(!IsExpertEnabled()) print_and_email("Error","The EA can't close ticket "+IntegerToString(ticket)+" because EAs are not enabled in the trading platform.");
        else if(IsTradeContextBusy()) print_and_email("Error","The EA can't close ticket "+IntegerToString(ticket)+" because the trade context is busy.");
        else if(!IsTradeAllowed()) print_and_email("Error","The EA can't close ticket "+IntegerToString(ticket)+" because the close order is not allowed while a thread for trading is occupied.");
        else result=exit_order(ticket,max_slippage_pips,a_color);
        if(result)
          break;
        // TODO: setup an email and SMS alert.
        // Make sure to use OrderSymbol() instead of symbol to get the instrument of the order.
        print_and_email("Error","Closing order# "+IntegerToString(OrderTicket(),0)+" failed. Last Error: "+IntegerToString(GetLastError(),0));
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
                      if(actual_type==OP_BUY) try_to_exit_order(ticket,max_slippage_pips); break;
                    case ORDER_SET_SELL:
                      if(actual_type==OP_SELL) try_to_exit_order(ticket,max_slippage_pips); break;
                    case ORDER_SET_BUY_LIMIT:
                      if(actual_type==OP_BUYLIMIT) try_to_exit_order(ticket,max_slippage_pips); break;
                    case ORDER_SET_SELL_LIMIT:
                      if(actual_type==OP_SELLLIMIT) try_to_exit_order(ticket,max_slippage_pips); break;
                    case ORDER_SET_LONG:
                      if(actual_type==OP_BUY || actual_type==OP_BUYLIMIT /*|| ordertype==OP_BUYSTOP*/)
                        try_to_exit_order(ticket,max_slippage_pips); break;
                    case ORDER_SET_SHORT:
                      if(actual_type==OP_SELL || actual_type==OP_SELLLIMIT /*|| ordertype==OP_SELLSTOP*/)
                        try_to_exit_order(ticket,max_slippage_pips); break;
                    case ORDER_SET_LIMIT:
                      if(actual_type==OP_BUYLIMIT || actual_type==OP_SELLLIMIT)
                        try_to_exit_order(ticket,max_slippage_pips); break;
                    case ORDER_SET_MARKET:
                      if(actual_type<=1) try_to_exit_order(ticket,max_slippage_pips); break;
                    case ORDER_SET_PENDING:
                      if(actual_type>1) try_to_exit_order(ticket,max_slippage_pips); break;
                    default: try_to_exit_order(ticket,max_slippage_pips); // this is the case where type==ORDER_SET_ALL falls into
                  }
              }
          }
      }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_acceptable_spread(string instrument,double _max_spread_percent,bool _based_on_specific_spread,bool _based_on_raw_ADR=true,double spread_pts_provided=0,bool refresh_rates=false)
  {
    double _spread_pts=0,max_spread=2;
    int    digits=(int)MarketInfo(instrument,MODE_DIGITS);
    double range_pts=HOP_price-LOP_price;
    if(refresh_rates) RefreshRates();
    if(_based_on_raw_ADR==_based_on_specific_spread)
      {
        print_and_email("Error","is_acceptable_spread: Coding error: you cannot have _based_on_raw_ADR==_based_on_specific_spread");
         return false;
      }
    if(spread_pts_provided==0)
      {
        double point=MarketInfo(instrument,MODE_POINT);
        _spread_pts=NormalizeDouble(MarketInfo(instrument,MODE_SPREAD)*point*point_multiplier/spread_divider,digits); //  I put this check here because the rates were just refreshed.
      }
    else
      {
        _spread_pts=spread_pts_provided;
      }
    if(ADR_pts_raw>0 && _based_on_raw_ADR)
      {
        double _ADR_pts_raw=ADR_pts_raw;
        _ADR_pts_raw=MathMax(range_pts,ADR_pts_raw);
        max_spread=NormalizeDouble(_ADR_pts_raw*_max_spread_percent,digits);
      }
    else if(_based_on_specific_spread)
      {
        max_spread=get_acceptable_spread(instrument,_spread_pts);
      }
    else if(ADR_pts>0)
      {
        if(ADR_pts_raw<=0) print_and_email("Warning","is_acceptable_spread: ADR_pts_raw for "+instrument+" is <=0");
        double _ADR_pts=ADR_pts;
        _ADR_pts=MathMax(range_pts,_ADR_pts);
        max_spread=NormalizeDouble(_ADR_pts*_max_spread_percent,digits);
      }
    if(compare_doubles(_spread_pts,max_spread,digits)<=0)
      return true;
    print_and_email("Warning"," is_acceptable_spread: The _spread_pts of "+DoubleToString(_spread_pts)+" is > "+DoubleToString(max_spread)+" for "+instrument+" so a trade will be prevented");
    return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculate_avg_spread_yesterday(string instrument)
  {
   int    digits=(int)MarketInfo(instrument,MODE_DIGITS);
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
            double spread=NormalizeDouble(MarketInfo(instrument,MODE_SPREAD)*point*point_multiplier/spread_divider,Digits); // divide by 10
            spread_total+=spread;
          }
      }
    return NormalizeDouble(spread_total/(new_server_day_bar-end_server_day_bar),Digits); // return the average spread*/
    double avg_spread_yesterday=NormalizeDouble((MarketInfo(instrument,MODE_SPREAD)*point*point_multiplier)/spread_divider,digits); // this line is temporary until I find a way to get spread history
    //Print("calculate_avg_spread_yesterday() returns: ",avg_spread_yesterday);
    return avg_spread_yesterday;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_range_overblown(double multiplier)
  {
    if(HOP_price-LOP_price>ADR_pts*multiplier) return true;
    else return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool expired_peak_level(datetime _current_time)
  {
    //if(peak_expire_seconds==0 || peak_expire_seconds==NULL) return false;
    if(retracement_percent>0)
      {
        datetime peak_levels_time;
        if(uptrend) 
          {
            peak_levels_time=HOP_time;
            //double price_diff_since_last_peak=current_pivot_level_price-last_pivot_levels_price;
          }
        else if(downtrend)
          {
            peak_levels_time=LOP_time;
            //double price_diff_since_last_peak=last_pivot_levels_price-current_pivot_level_price;
          }
        else return false;
        int seconds_since_peak=int(_current_time-peak_levels_time);
        //int seconds_since_pivot=int(peak_levels_time-pivot_levels_time);
        //if(is_new_M5_bar) Print("Peak time: ",TimeToString(pivot_levels_time)," Minutes since peak: ",seconds_since_peak/60);
        if(seconds_since_peak>int(retracement_virtual_expire*3600)/*&& price_diff_since_last_peak>=ADR_pts*(ADR_pts*.1)*/)
          {
            //Print("Prevented a trade because it did not meet the expire_seconds from peak criteria");
            return true;
          }
      }
    return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool expired_pivot_level(datetime _current_time)
  {
    datetime pivot_levels_time;
    //datetime peak_levels_time;
    //if(peak_expire_sec==0 || peak_expire_sec==NULL) return false;
    if(uptrend) 
      {
        pivot_levels_time=LOP_time;
        //peak_levels_time=HOP_price;
      }
    else if(downtrend)
      {
        pivot_levels_time=HOP_time;
        //peak_levels_time=LOP_price;
      }
    else return false;
    int seconds_since_pivot=int(_current_time-pivot_levels_time);
    //int seconds_pivot_to_peak=int(peak_levels_time-pivot_levels_time);
    int setups_max_time=int((H1s_to_roll*3600)+int(retracement_virtual_expire*3600)+int(trigger_to_peak_max*3600)+361);
    if(seconds_since_pivot>setups_max_time)
      {
        //Print("expired_pivot_level: returned true");
        return true;
      }
    return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void try_to_enter_order(ENUM_ORDER_TYPE type,int magic,int max_slippage_pips,string instrument,bool _reduced_risk,int _max_risky_trades,double current_bid)
  {
    double pending_order_distance_pts=0; // keep at 0
    double periods_pivot_price;
    color  arrow_color;
    int    digits=(int)MarketInfo(instrument,MODE_DIGITS);
    double point=MarketInfo(instrument,MODE_POINT);
    double takeprofit_pts=0,stoploss_pts=0;
    double _pullback_percent=pullback_percent;
    double _retracement_percent=retracement_percent;
    double periods_range_pts=ADR_pts; // keep as ADR_pts
    double ma_price=iMA(instrument,PERIOD_M5,moving_avg_period,0,MODE_SMA,PRICE_MEDIAN,0);
    if(reverse_trade_direction) // TODO: should this code be run before or after range_pts_calculation is run? I think before because the periods_range_pts need to be calculated as if it was not a reverse trade.
      {
        if(type==OP_BUY) type=OP_SELL;
        else if(type==OP_SELL) type=OP_BUY;
      }
    if(_pullback_percent==NULL) 
      {
        _pullback_percent=0;
      }
    else if(_pullback_percent<0) 
      {
        print_and_email("Error","pullback_percent cannot be less than 0");
        platform_alert("Error","pullback_percent cannot be less than 0");
        return;
      }
    if(_retracement_percent>0)
      {
        periods_range_pts=HOP_price-LOP_price; // (this will also work:) periods_range_pts=range_pts_calculation(type,instrument); // TODO: is it okay that the periods_range_pts is calculated with the type before the reverse_trade_direction code runs?
        if(periods_range_pts<ADR_pts)
          {
            print_and_email("Warning","A "+instrument+" trade entry was just attempted with a periods_range_pts of "+DoubleToStr(periods_range_pts,digits)+" (which is less than ADR_pts "+DoubleToStr(ADR_pts,digits)+").");
            Print("HOP_time: ",TimeToStr(HOP_time)," LOP_time: ",TimeToStr(LOP_time));
            Print("HOP_price: ",DoubleToStr(HOP_price)," LOP_price: ",DoubleToStr(LOP_price));
            //enter_signal=DIRECTION_BIAS_NEUTRALIZE;
          }
        if(_pullback_percent>0) pending_order_distance_pts=NormalizeDouble((_retracement_percent+_pullback_percent)*periods_range_pts,digits); 
      }
    else
      {
        if(_pullback_percent>0) pending_order_distance_pts=NormalizeDouble(_pullback_percent*periods_range_pts,digits);
      }
    //Print("try_to_enter_order(): distance_pts: ",DoubleToString(pullback_distance_pts));
    if(type==OP_BUY)
      {
        if(reverse_trade_direction) arrow_color=clrRed;
        else arrow_color=clrGreen;
        if(_retracement_percent>0 && LOP_price>0) periods_pivot_price=LOP_price;
        else periods_pivot_price=periods_pivot_price(BUYING_MODE,instrument);
      }
    else if(type==OP_SELL)
      {
        if(reverse_trade_direction) arrow_color=clrGreen;
        else arrow_color=clrRed;
        if(_retracement_percent>0 && HOP_price>0) periods_pivot_price=HOP_price;
        else periods_pivot_price=periods_pivot_price(SELLING_MODE,instrument);
      }
    else 
      {
        print_and_email("Error","The algorithm programmer can only use OP_BUY and OP_SELL for signals.");
        return;
      }
    // This part checks to see if the market order is too risky to be made while running with other instances of the algorithm in the same account and, if so, a trade gets simulated but not actually executed. 
    // The trade simulation is important because it affects other functions.
    if(_pullback_percent==0) // if it is a market order signal
      {
        ENUM_DIRECTION_BIAS bias=DIRECTION_BIAS_IGNORE;
        int temp_type=type;
        string current_chart=Symbol();
        bool current_chart_matches=(current_chart==instrument);
        if(reverse_trade_direction) // since it may not pass through the final reverse_trade_direction in the send_and_get_ticket function, a temporary reverse_trade_direction has to be done here
          {
            // this only switches the order_type for both instant and market executions in this scope
            if(temp_type==OP_BUY) temp_type=OP_SELL;
            else if(temp_type==OP_SELL) temp_type=OP_BUY;
          } 
        if(temp_type==OP_BUY)
          {
            downtrend_order_was_last=false;
            uptrend_order_was_last=true;
            if(current_chart_matches && display_chart_objects)
              {
                ObjectSet(current_chart+"_HOP",OBJPROP_WIDTH,1);
                ObjectSetString(0,current_chart+"_last_order_direction",OBJPROP_TEXT,"uptrend SIGNAL(not order) was last");
              }
            bias=signal_check_risky_market_trade(instrument,DIRECTION_BIAS_BUY,_max_risky_trades);            
          }
        else if(temp_type==OP_SELL)
          {
            uptrend_order_was_last=false;
            downtrend_order_was_last=true;
            if(current_chart_matches && display_chart_objects)
              {
                ObjectSet(current_chart+"_LOP",OBJPROP_WIDTH,1);
                ObjectSetString(0,current_chart+"_last_order_direction",OBJPROP_TEXT,"downtrend SIGNAL(not order) was last");
              }
            bias=signal_check_risky_market_trade(instrument,DIRECTION_BIAS_SELL,_max_risky_trades);      
          }
        if(bias<=0 && bias!=DIRECTION_BIAS_IGNORE && bias!=NULL) 
            return; // do not make any trades but they have been simulated in order to pretend they have been made
      }
    // If the flow reaches this point, the trade should really be made and not simulated.
    RefreshRates();
    double spread_pts=NormalizeDouble(MarketInfo(instrument,MODE_SPREAD)*point*point_multiplier/spread_divider,digits);
    if(prevent_ultrawide_stoploss) periods_range_pts=MathMin(periods_range_pts,ADR_pts); // Does not allow the stoploss and takeprofit to be more than ADR_pts. This line must go above the lots, takeprofit_pts and stoploss_pts calculations.
    double lots;
    lots=calculate_lots(money_management,periods_range_pts,risk_percent_per_range,spread_pts,instrument,magic,_reduced_risk,ma_price);
    double new_takeprofit_percent=get_new_takeprofit_percent(instrument,periods_range_pts,digits,current_bid,ma_price);
    takeprofit_pts=NormalizeDouble(periods_range_pts*new_takeprofit_percent,digits);
    stoploss_pts=NormalizeDouble((periods_range_pts*stoploss_percent)-pending_order_distance_pts-(periods_range_pts*_retracement_percent),digits);
    print_and_email_margin_info(instrument,"Margin Info Before Trying To Enter Trade");
    int ticket=check_for_entry_errors (instrument,
                                       type,
                                       lots,
                                       pending_order_distance_pts, // it should always be 0 or positive
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
    if(ticket>0)
      {
        if(pullback_percent!=0) cleanup_risky_pending_orders(instrument);
        print_and_email_margin_info(instrument,"Margin Info After Entering Trade");
      }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double get_new_takeprofit_percent(string instrument,double _periods_range_pts,int _digits,double current_bid,double _ma_price)
  {
    double _takeprofit_percent;
    if(takeprofit_pts_is_ma_distance_based && moving_avg_period>0 && takeprofit_percent>0)
      {
        //double ma_price=iMA(instrument,PERIOD_M5,moving_avg_period,0,MODE_SMA,PRICE_MEDIAN,0);
        double ma_distance_pts=MathAbs(current_bid-_ma_price);
        double distance_percent=NormalizeDouble(ma_distance_pts/ADR_pts_raw,2);
        //if(distance_percent<0) distance_percent=0;
        _takeprofit_percent=MathMin((takeprofit_percent*distance_percent),takeprofit_percent)+takeprofit_percent;
        set_new_active_trade_expire(_takeprofit_percent);
      }
    else
        _takeprofit_percent=takeprofit_percent; // do not put this calculation into the parameter of the check_for_entry_errors function // TODO: In your trading rules, should you put this line above "periods_range_pts=MathMin(periods_range_pts,ADR_pts);"?
    return _takeprofit_percent;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void set_new_active_trade_expire(double _new_takeprofit_percent)
  {
    if(active_trade_expire_is_tp_based)
      {
        if(takeprofit_percent>0)
          {
            double change_percent=MathMin(NormalizeDouble((_new_takeprofit_percent/takeprofit_percent),2),active_trade_expire*2);
            if(change_percent<1) return;
            else active_trade_expire=NormalizeDouble(active_trade_expire*change_percent,2); // Note: this will be changed back to the original value stored in active_trade_expire_stored after the trade closes as seen in the main_script_ran function
          }
        else
            print_and_email("Warning","set_new_active_trade_expire: takeprofit_percent cannot be <=0 if you want to make active_trade_expire based on takeprofit.");
      }
  }
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
int check_for_entry_errors(string instrument,int cmd,double lots,double _distance_pts,double periods_pivot_price,double sl_pts,double tp_pts,int max_slippage,double spread_points,double range_pts,string _EA_name=NULL,int magic=0,int expire=0,color a_clr=clrNONE,bool market=false,int _retries=3,int sleep_milisec=1000)
  {
    int ticket=0;
    for(int i=0;i<_retries;i++)
      {
        if(IsStopped()) print_and_email("Error","The EA can't enter a trade because the EA is stopped.");
        else if(!IsConnected()) print_and_email("Error","The EA can't enter a trade because there is no internet connection.");
        else if(!IsExpertEnabled()) print_and_email("Error","The EA can't enter a trade because EAs are not enabled in trading platform.");
        else if(IsTradeContextBusy()) print_and_email("Error","The EA can't enter a trade because the trade context is busy.");
        else if(!IsTradeAllowed()) print_and_email("Error","The EA can't enter a trade because the trade is not allowed while a thread for trading is occupied.");
        else ticket=send_and_get_order_ticket(instrument,cmd,lots,_distance_pts,periods_pivot_price,sl_pts,tp_pts,max_slippage,spread_points,range_pts,_EA_name,magic,expire,a_clr,market);
        if(ticket>0) break;
        else
          {
            // TODO: setup an email and SMS alert.
            print_and_email("Error",instrument+" , "+WindowExpertName()+": A "+IntegerToString(cmd)+" order was attempted but it did not succeed. If there are no errors here, market factors may not have met the code's requirements within the send_and_get_order_ticket function. Last Error:, ("+IntegerToString(GetLastError(),0)+"), Retry: "+IntegerToString(i,0)+"/"+IntegerToString(retries));
            //Alert(instrument," , ",WindowExpertName(),": A ",cmd," order was attempted but it did not succeed. Check the Journal tab of the Navigator window for errors.");
          }
        Sleep(sleep_milisec);
      }
    //Print("ticket: ",IntegerToString(ticket));
    return ticket;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void unacceptable_spread_message(double spread_pts,string instrument)
  {
    double percent_allows_trading=NormalizeDouble(((average_spread_yesterday-(ADR_pts*max_spread_percent))/ADR_pts)+max_spread_percent,3);
    string message=StringConcatenate (instrument,": The signal to enter can't be sent because the current spread does not meet your max_spread_percent (",
                                      DoubleToStr(max_spread_percent,3),") of ADR criteria. The average spread yesterday was ",
                                      DoubleToStr(average_spread_yesterday,3),
                                      " but the current spread (",DoubleToStr(spread_pts,2),") is not acceptable. A max_spread_percent value above ",
                                      DoubleToStr(percent_allows_trading,3),
                                      " would have allowed the algorithm to make this trade.");
    print_and_email("Warning",message);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// the distanceFromCurrentPrice parameter is used to specify what type of order you would like to enter
// Documentation: Requirements and Limitions in Making Trades https://book.mql4.com/appendix/limits
int send_and_get_order_ticket(string instrument,int cmd,double lots,double _distance_pts,double periods_pivot_price,double sl_pts,double tp_pts,int max_slippage,double spread_pts,double range_pts,string _EA_name=NULL,int magic=0,int expire=0,color a_clr=clrNONE,bool _market_exec=false) // the "market" argument is to make this function compatible with brokers offering market execution. By default, it uses instant execution.
  {
    double     entry_price=0, price_sl=0, price_tp=0;
    double     point=MarketInfo(instrument,MODE_POINT);
    double     min_distance_pts=MarketInfo(instrument,MODE_STOPLEVEL)*point*point_multiplier;
    int        digits=(int)MarketInfo(instrument,MODE_DIGITS);
    //RefreshRates(); // may not be necessary since rates were extremely recently refreshed in try_to_enter_order function
    double     current_ask=MarketInfo(instrument,MODE_ASK);
    double     current_bid=MarketInfo(instrument,MODE_BID);
    string     current_chart=Symbol();
    datetime   expire_time=0; // 0 means there is no expiration time for a pending order
    int        order_type=-1; // -1 means there is no order because actual orders are >=0
    bool       instant_exec=!_market_exec;
    int        ticket=0;
    //Print("send_and_get_order_ticket(): tp_pts before adding spread_pts: ",DoubleToString(tp_pts)); 
    tp_pts+=spread_pts; // increase the take profit so the user can get the full pips of profit they wanted if the take profit price is hit
    //if(range_pts>ADR_pts) _ADR_pts=range_pts;
    /*Print("send_and_get_order_ticket(): lots: ",DoubleToString(lots));
    Print("send_and_get_order_ticket(): _distance_pts: ",DoubleToString(_distance_pts));
    Print("send_and_get_order_ticket(): min_distance_pts: ",DoubleToString(min_distance_pts));
    Print("send_and_get_order_ticket(): current_price: ",DoubleToString(current_bid));
    Print("send_and_get_order_ticket(): periods_pivot_price: ",DoubleToString(periods_pivot_price));
    Print("send_and_get_order_ticket(): max_slippage: ",IntegerToString(max_slippage));
    Print("send_and_get_order_ticket(): spread_pts: ",DoubleToString(spread_pts));
    Print("send_and_get_order_ticket(): tp_pts: ",DoubleToString(tp_pts));
    Print("send_and_get_order_ticket(): sl_pts: ",DoubleToString(sl_pts));
    Print("send_and_get_order_ticket(): magic: ",IntegerToString(magic));*/
    /*if(reverse_trade_direction)
      {
        if(cmd==OP_BUY) cmd=OP_SELL;
        else if(cmd==OP_SELL) cmd=OP_BUY;
      }*/
    bool is_acceptable_spread=true;
    if(max_spread_percent>0) is_acceptable_spread(instrument,max_spread_percent,false,true,spread_pts,false);
    //Print("send_and_get_order_ticket(): is_acceptable_spread: ",is_acceptable_spread);
    if(is_acceptable_spread==false) 
      {
        // Keeps the EA from entering trades when the spread is too wide for market orders (but not pending orders). Note: It may never enter on exotic currencies (which is good automation).
        unacceptable_spread_message(spread_pts,instrument);
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
    string generated_comments;
    if(breakeven_threshold_percent>0 || trail_threshold_percent>0) generated_comments=DoubleToStr(range_pts,digits); // check the breakeven function before changing this line because the breakeven function uses the contents of the comments to work
    else generated_comments=generate_comment(instrument,magic,sl_pts,tp_pts,spread_pts);
    if(instant_exec)
      {
        //Print("instant_exec expire_time=",expire_time);
        /*Print("send_and_get_order_ticket(): entry_price: ",DoubleToString(entry_price,digits));        
        Print("send_and_get_order_ticket(): current_bid: ",DoubleToString(current_bid,digits));
        Print("send_and_get_order_ticket(): current_ask: ",DoubleToString(current_ask,digits));
        Print("send_and_get_order_ticket(): price_sl: ",DoubleToString(price_sl,digits));
        Print("send_and_get_order_ticket(): price_tp: ",DoubleToString(price_tp,digits));
        Print("send_and_get_order_ticket(): price_tp-entry_price: ",DoubleToString(MathAbs(price_tp-entry_price),digits));
        Print("send_and_get_order_ticket(): price_sl-entry_price: ",DoubleToString(MathAbs(price_sl-entry_price),digits));
        Print("instrument: ",instrument,", ordertype: ",order_type,", lots: ",lots,", entryprice: ",DoubleToString(entry_price),", max_slippage: ",IntegerToString(max_slippage),", price_sl: ",DoubleToString(price_sl),", price_tp: ",price_tp,", magic: ",magic,", expire_time: ",expire_time);*/
        if(order_type==OP_BUYLIMIT && reverse_trade_direction==false)
          {
            // alert the user of the algorithm if there will be a problem with their order
            if(compare_doubles(current_ask-entry_price,min_distance_pts,digits)==-1) print_and_email("Error",instrument+": If BuyLimit, this will result in an Open Price error because current_ask-entry_price("+DoubleToString(current_ask-entry_price)+")<min_distance_pips");
            if(compare_doubles(entry_price-price_sl,min_distance_pts,digits)==-1)    print_and_email("Error",instrument+": If BuyLimit, this will result in an Stoploss error because entry_price-price_sl("+DoubleToString(entry_price-price_sl)+")<min_distance_pips");
            if(compare_doubles(price_tp-entry_price,min_distance_pts,digits)==-1)    print_and_email("Error",instrument+": If BuyLimit, this will result in an Takeprofit error because price_tp-entry_price("+DoubleToString(price_tp-entry_price)+")<min_distance_pips");
          }
        ticket=OrderSend(instrument,order_type,lots,NormalizeDouble(entry_price,digits),max_slippage,NormalizeDouble(price_sl,digits),NormalizeDouble(price_tp,digits),generated_comments,magic,expire_time,a_clr);
        if(ticket>0)
          {
            if(OrderSelect(ticket,SELECT_BY_TICKET))
              {
                if(order_type==OP_BUY || order_type==OP_BUYLIMIT)
                  {
                    downtrend_order_was_last=false;
                    uptrend_order_was_last=true;
                    ObjectSet(current_chart+"_HOP",OBJPROP_WIDTH,1);
                    ObjectSetString(0,current_chart+"_last_order_direction",OBJPROP_TEXT,"uptrend order was last");
                  }
                else if(order_type==OP_SELL || order_type==OP_SELLLIMIT)
                  {
                    uptrend_order_was_last=false;
                    downtrend_order_was_last=true;
                    ObjectSet(current_chart+"_LOP",OBJPROP_WIDTH,1);
                    ObjectSetString(0,current_chart+"_last_order_direction",OBJPROP_TEXT,"downtrend order was last"); 
                  }
              }
          }
        //Print("returning instant_exec ticket");
        //return ticket;
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
        ticket=OrderSend(instrument,order_type,lots,NormalizeDouble(entry_price,digits),max_slippage,0,0,generated_comments,magic,expire_time,a_clr);
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
                    downtrend_order_was_last=false;
                    uptrend_order_was_last=true;
                    ObjectSet(current_chart+"_HOP",OBJPROP_WIDTH,1);
                    ObjectSetString(0,current_chart+"_last_order_direction",OBJPROP_TEXT,"uptrend order was last");
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
                    uptrend_order_was_last=false;
                    downtrend_order_was_last=true;
                    ObjectSet(current_chart+"_LOP",OBJPROP_WIDTH,1);
                    ObjectSetString(0,current_chart+"_last_order_direction",OBJPROP_TEXT,"downtrend order was last");
                  }
                //Print("send_and_get_order_ticket(): price_sl: ",DoubleToString(price_sl,digits));
                //Print("send_and_get_order_ticket(): price_tp: ",DoubleToString(price_tp,digits));
                bool result=try_to_modify_order(ticket,NormalizeDouble(price_sl,digits),retries,NormalizeDouble(price_tp,digits),expire_time);
              }
          }
        //Print("send_and_get_ticket: returned market_exec ticket");
        //return ticket;
      }
    else 
      {
        print_and_email("Warning","send_and_get_ticket returned 0 because the execution was neither market execution nor instant execution");
        return 0;
      }
    if(ticket>0) 
      {
        string subject="Info: A "+instrument+" Trade Was Entered";
        string email_body=StringConcatenate(subject,
                                            ". Details: entry_price: ",DoubleToString(entry_price,digits),
                                            ", target_points: ",DoubleToString(MathAbs(price_sl-price_tp)),
                                            ", price_sl: ",DoubleToString(price_sl,digits),
                                            ", price_tp: ",DoubleToString(price_tp,digits),
                                            ", ticket: ",IntegerToString(ticket)
                                           );  
        print_and_email(subject,email_body);
      }  
    return ticket;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculate_lots(ENUM_MM method,double range_pts,double _risk_percent_per_ADR,double spread_pts,string instrument,int magic,bool _reduced_risk,double _ma_price)
  {
    double points=0;
    double _stoploss_percent=stoploss_percent;
    int    digits=(int)MarketInfo(instrument,MODE_DIGITS);
    if(method==MM_RISK_PERCENT_PER_ADR)
      points=NormalizeDouble(range_pts+spread_pts,digits); // Increase the Average Daily (pip) Range by adding the average (pip) spread because it is additional pips at risk everytime a trade is entered. As a result, the lots that get calculated will be lower (which will slightly reduce the risk).
    else if(range_pts>0 && _stoploss_percent>0)
      points=NormalizeDouble((range_pts*_stoploss_percent)+spread_pts,digits); // it could be 0 if stoploss_percent is set to 0 
    else 
      points=NormalizeDouble(range_pts+spread_pts,digits);
    double lots=get_lots(method,
                         _reduced_risk,
                         magic,
                         instrument,
                         _risk_percent_per_ADR,
                         points,
                         mm1_risk_percent,_ma_price);
    return lots;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// TODO: is it pips or points that the 4th parameter actually needs?
double get_lots(ENUM_MM method,bool _reduced_risk,int magic,string instrument,double _risk_percent_per_ADR,double pts,double risk_mm1_percent,double _ma_price)
  {
    double tick_value=MarketInfo(instrument,MODE_TICKVALUE);
    double point=MarketInfo(instrument,MODE_POINT);
    double lots=0;
    double balance=0;
    double lot_multiplier=1; // keep at 1
    double micro_multiplier=0; // micro account multiplier
    int    instrument_int=get_string_integer(StringSubstr(instrument,0,6));
    switch(instrument_int)
      {
        case EURJPY:
          micro_multiplier=point_multiplier*100; break;
        case EURUSD:
          micro_multiplier=point_multiplier*10000; break;
        case GBPJPY:
          micro_multiplier=point_multiplier*100; break;
        case GBPUSD:
          micro_multiplier=point_multiplier*10000; break;
        case USDCHF:
          micro_multiplier=point_multiplier*10000; break;
        case USDJPY:
          micro_multiplier=point_multiplier*100; break;
        default:
          micro_multiplier=0;
      }    
    if(compound_balance || AccountBalance()<5000) balance=AccountBalance();
    else balance=5000;
    switch(method)
      {
        case MM_RISK_PERCENT_PER_ADR:
          if(pts>0) lots=((balance*_risk_percent_per_ADR)/pts)/(tick_value*micro_multiplier); break;
        case MM_RISK_PERCENT:
          if(pts>0) lots=((balance*risk_mm1_percent)/pts)/(tick_value*micro_multiplier); break;
        /*case MM_FIXED_RATIO:
          lots=balance*lots_mm2/per_mm2; break;
        case MM_FIXED_RISK:
          if(pips>0) lots=(risk_mm3/tick_value)/pts; break;
        case MM_FIXED_RISK_PER_POINT:
          lots=risk_mm4/tick_value; break;*/
      }
    if(increase_lots_by_percent>0 && increase_lots_after_x_losses>0)
      if(last_x_trades_were_loss(increase_lots_after_x_losses,magic))
        {
          lot_multiplier+=increase_lots_by_percent;
          //if(lot_multiplier>1) Print("THE LOT_MULTIPLIER WAS INCREASED");
        }
    // get information from the broker and then Normalize the lots double
    double min_lots=MarketInfo(instrument,MODE_MINLOT);
    double max_lots=MarketInfo(instrument,MODE_MAXLOT);
    int lot_digits=int(-MathLog10(MarketInfo(instrument,MODE_LOTSTEP))); // MathLog10 returns the logarithm of a number (in this case, the MODE_LOTSTEP) base 10. So, this finds out how many digits in the lot the broker accepts.
    if(_reduced_risk==true) 
      {
        //Print("lots before changing: ",DoubleToStr(NormalizeDouble(lots*lot_multiplier,lot_digits)));
        lot_multiplier=lot_multiplier*.5;
        //Print("lots after changing: ",DoubleToStr(NormalizeDouble(lots*lot_multiplier,lot_digits)));
      }
    else if(lot_size_is_ma_distance_based && moving_avg_period>0) // note: setting lot_size_is_ma_distance_based==true doesn't increase the profit factor
      {
          //double ma_price=iMA(instrument,PERIOD_M5,moving_avg_period,0,MODE_SMA,PRICE_MEDIAN,0);
          double ma_distance_pts=MathAbs(Bid-_ma_price); // this variable corresponds to the get_lots function
          double distance_percent=NormalizeDouble(ma_distance_pts/ADR_pts_raw,2);
          Print("trade's distance_percent: ",DoubleToString(distance_percent,2));
          /*if(distance_percent>=1.50)    lot_multiplier=lot_multiplier*1.50;
          else if(distance_percent>=1.25) lot_multiplier=lot_multiplier*1.25;
          else if(distance_percent>=1.00) lot_multiplier=lot_multiplier*1.00;
          else if(distance_percent>=0.75) lot_multiplier=lot_multiplier*0.75;
          else if(distance_percent>=0.50) lot_multiplier=lot_multiplier*0.50;
          else                            lot_multiplier=lot_multiplier*0.25;*/
          lot_multiplier=MathMin(distance_percent,1)*lot_multiplier;
      }
    lots=NormalizeDouble(lots*lot_multiplier,lot_digits);
    // If the lots value is below or above the broker's MODE_MINLOT or MODE_MAXLOT, the lots will be change to one of those lot sizes. This is in order to prevent Error 131 - invalid trade volume
    if(lots<min_lots) lots=min_lots;
    if(lots>max_lots) lots=max_lots;
    return lots;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double get_acceptable_spread(string instrument,double _spread_pts)
  {
    double max_spread;
    int    instrument_int=get_string_integer(StringSubstr(instrument,0,6));
   double  point=MarketInfo(instrument,MODE_POINT);
    switch(instrument_int)
      {
        case EURUSD:
          return max_spread=point*point_multiplier*2.5;
        default:
          print_and_email("Error","get_acceptable_spread: "+instrument+"'s maximum spread value for is not coded.");
          return false;
      }
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
                      if(actual_type==OP_BUY) count++; break;
                    case ORDER_SET_SELL:
                      if(actual_type==OP_SELL) count++; break;
                    case ORDER_SET_BUY_LIMIT:
                      if(actual_type==OP_BUYLIMIT) count++; break;
                    case ORDER_SET_SELL_LIMIT:
                      if(actual_type==OP_SELLLIMIT) count++; break;
                    /*case ORDER_SET_BUY_STOP:
                      if(actual_type==OP_BUYSTOP) count++; break;
                    case ORDER_SET_SELL_STOP:
                      if(actual_type==OP_SELLSTOP) count++; break;*/
                    case ORDER_SET_LONG:
                      if(actual_type==OP_BUY || actual_type==OP_BUYLIMIT /*|| actual_type==OP_BUYSTOP*/)
                        count++; break;
                    case ORDER_SET_SHORT:
                      if(actual_type==OP_SELL || actual_type==OP_SELLLIMIT /*|| actual_type==OP_SELLSTOP*/)
                        count++; break;
                    case ORDER_SET_SHORT_LONG_LIMIT_MARKET:
                      if(actual_type==OP_BUY || actual_type==OP_BUYLIMIT || actual_type==OP_SELL || actual_type==OP_SELLLIMIT /*|| ordertype==OP_SELLSTOP*/)
                        count++; break;
                    case ORDER_SET_LIMIT:
                      if(actual_type==OP_BUYLIMIT || actual_type==OP_SELLLIMIT)
                        count++; break;
                    /*case ORDER_SET_STOP:
                      if(actual_type==OP_BUYSTOP || actual_type==OP_SELLSTOP)
                        count++; break;*/
                    case ORDER_SET_MARKET:
                      if(actual_type<=1) count++; break;
                    case ORDER_SET_PENDING:
                      if(actual_type>1) count++; break;
                    default: 
                      count++;
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
    if(ticket<=0) return true; // if it is not a valid ticket
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
void trailingstop_check_order(int ticket,double _threshold_percent,double _step_percent=.2)
  {
    if(ticket<=0) return; // if it is not a valid ticket
    if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES)) return;
    int order_type=OrderType();
    if(order_type>2) return; // if it is not an active trade, return
    int digits=(int)MarketInfo(OrderSymbol(),MODE_DIGITS);
    double current_sl=OrderStopLoss();
    double trail_pts=ADR_pts;
    double periods_range_pts=StringToDouble(OrderComment());
    if(_step_percent==0) _step_percent=.2;
    if(retracement_percent>0 && pullback_percent==0)
      {
        //order_sl_pts=MathAbs(current_sl-OrderOpenPrice());
        //if(compare_doubles(order_sl_pts,ADR_pts,digits)==-1) order_sl_pts=ADR_pts;
        trail_pts=NormalizeDouble(periods_range_pts-(periods_range_pts*retracement_percent),digits);
      }
    else if(pullback_percent>0 && retracement_percent==0)
      {
        trail_pts=NormalizeDouble(periods_range_pts-(periods_range_pts*pullback_percent),digits);
      }
    else trail_pts=ADR_pts;
    if(order_type==OP_BUY)
      {
        if(current_sl==0 || current_sl==NULL) 
          {
            try_to_modify_order(ticket,NormalizeDouble(OrderOpenPrice()-trail_pts,digits),retries);
            return;
          }
        if(current_sl-OrderOpenPrice()>=0) return; // Turn off trailing stop if the stoploss is at breakeven or above. This line should be above all the calculations. If it is true, all those calculations do not need to be done.
        double threshold_pts=NormalizeDouble(_threshold_percent*(takeprofit_percent*periods_range_pts),digits);
        double thresholds_activation_price=OrderOpenPrice()+threshold_pts;
        if(compare_doubles(OrderClosePrice(),thresholds_activation_price,digits)>=0) // if price is above the threshold
          {
            
            double step_pts=NormalizeDouble(_step_percent*(takeprofit_percent*periods_range_pts),digits);
            double moving_sl=OrderClosePrice()-trail_pts; // the current price - the trail in points
            double step_in_pts=moving_sl-current_sl; // keeping track of the distance between the potential stoploss and the current stoploss
            if(compare_doubles(step_in_pts,step_pts,digits)>=0) 
              {      
                double new_sl=MathMax(thresholds_activation_price-trail_pts,OrderStopLoss()+step_pts);
                try_to_modify_order(ticket,NormalizeDouble(new_sl,digits),retries); // if price met the step, move the stoploss
              }  
          }
      }
    else if(order_type==OP_SELL)
      {
       if(current_sl==0 || current_sl==NULL) 
          {
            try_to_modify_order(ticket,NormalizeDouble(OrderOpenPrice()+trail_pts,digits),retries);
            return;
          }
        if(OrderOpenPrice()-current_sl>=0) return; // Turn off trailing stop if the stoploss is at breakeven or above. This line should be above all the calculations. If it is true, all those calculations do not need to be done.
        double threshold_pts=NormalizeDouble(_threshold_percent*(takeprofit_percent*periods_range_pts),digits);
        double thresholds_activation_price=OrderOpenPrice()-threshold_pts;
        if(compare_doubles(OrderClosePrice(),thresholds_activation_price,digits)<=0) // if price is above the threshold
          {
            double step_pts=NormalizeDouble(_step_percent*(takeprofit_percent*periods_range_pts),digits);
            double moving_sl=OrderClosePrice()+trail_pts; // the current price - the trail in points
            double step_in_pts=current_sl-moving_sl; // keeping track of the distance between the potential stoploss and the current stoploss
            if(compare_doubles(step_in_pts,step_pts,digits)>=0) 
              {      
                double new_sl=MathMin(thresholds_activation_price+trail_pts,OrderStopLoss()-step_pts);
                try_to_modify_order(ticket,NormalizeDouble(new_sl,digits),retries); // if price met the step, move the stoploss
              }  
          }
      }
    return;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void trailingstop_check_all_orders(double _threshold_percent,double _step_percent,int magic=-1)
  {
    for(int i=0;i<OrdersTotal();i++)
      {
        if(OrderSelect(i,SELECT_BY_POS))
          {
            if(magic==-1 || magic==OrderMagicNumber())
            trailingstop_check_order(OrderTicket(),_threshold_percent,_step_percent);
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
void breakeven_check_order(int ticket,double threshold_percent,double plus_percent) 
  {
    if(ticket<=0) return; // if it is not a valid ticket
    if(!OrderSelect(ticket,SELECT_BY_TICKET) || plus_percent<0) return; // if there is no ticket, it cannot be processed
    int ordertype=OrderType();
    if(ordertype<=1)
      {
        double plus_pts=0;
        double order_open=OrderOpenPrice(),order_sl=OrderStopLoss();
        double periods_range_pts=StringToDouble(OrderComment());
        int    digits=(int)MarketInfo(OrderSymbol(),MODE_DIGITS);
        double threshold_pts=NormalizeDouble(threshold_percent*(takeprofit_percent*periods_range_pts),digits);
        //double negative_threshold_multiplier=2;
        double negative_threshold=threshold_pts*-negative_threshold_multiplier;
        if(ordertype==OP_BUY)
          {
            if(order_sl!=0 && compare_doubles(order_sl,order_open,digits)>=0) return;
            double point_gain=OrderClosePrice()-order_open; // calculate how many points in profit the trade is in so far
            if(compare_doubles(point_gain,threshold_pts,digits)>=0)
              {
                //if it gets to this point, the stoploss should be modified
                if(plus_percent>0) plus_pts=NormalizeDouble(plus_percent*(takeprofit_percent*periods_range_pts),digits);
                double new_sl=order_open+plus_pts; // calculate the price of the new stoploss
                try_to_modify_order(ticket,NormalizeDouble(new_sl,digits),retries);
                //Print("previous sl: ",DoubleToStr(order_sl,digits),", new breakeven sl: ",DoubleToStr(new_sl,digits));
                Print("point_gain: ",DoubleToStr(point_gain,digits),", threshold_pts: ",DoubleToStr(threshold_pts,digits));
              }
            else if(negative_threshold_multiplier>0 && compare_doubles(point_gain,negative_threshold,digits)<=0)
              {
                if(plus_percent>0) plus_pts=NormalizeDouble(plus_percent*(takeprofit_percent*periods_range_pts),digits);
                double new_tp=order_open+plus_pts; // calculate the price of the new stoploss
                try_to_modify_order(ticket,-1,retries,NormalizeDouble(new_tp,digits));        
              }
          }
        else if(ordertype==OP_SELL)
          {
            if(order_sl!=0 && compare_doubles(order_open,order_sl,digits)>=0) return;
            double point_gain=order_open-OrderClosePrice(); // calculate how many points in profit the trade is in so far
            if(compare_doubles(point_gain,threshold_pts,digits)>=0)
              {
                //if it gets to this point, the stoploss should be modified
                if(plus_percent>0) plus_pts=NormalizeDouble(plus_percent*(takeprofit_percent*periods_range_pts),digits);
                double new_sl=order_open-plus_pts; // calculate the price of the new stoploss
                try_to_modify_order(ticket,NormalizeDouble(new_sl,digits),retries);         
                //Print("previous sl: ",DoubleToStr(order_sl,digits),", new breakeven sl: ",DoubleToStr(new_sl,digits));
                Print("point_gain: ",DoubleToStr(point_gain,digits),", threshold_pts: ",DoubleToStr(threshold_pts,digits));
              }
            else if(negative_threshold_multiplier>0 && compare_doubles(point_gain,negative_threshold,digits)<=0)
              {
                if(plus_percent>0) plus_pts=NormalizeDouble(plus_percent*(takeprofit_percent*periods_range_pts),digits);
                double new_tp=order_open-plus_pts; // calculate the price of the new stoploss
                try_to_modify_order(ticket,-1,retries,NormalizeDouble(new_tp,digits));        
              }
          }
      }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void breakeven_check_all_orders(double threshold_percent,double plus_percent,int magic) // a -1 magic number means the there is no magic number in this order or EA
  {
    for(int i=0;i<OrdersTotal();i++)
      {
        if(OrderSelect(i,SELECT_BY_POS))
        if(OrderType()<=1 && (magic==-1 || magic==OrderMagicNumber()))
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
    double  point=MathPow(10,-precision); // 10^(-precision) // MathPow(base, exponent value)
    int     var1_int=(int)(var1/point);
    int     var2_int=(int)(var2/point);
    if(var1_int>var2_int)
      return 1;
    else if(var1_int<var2_int)
      return -1;
    return 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/*int count_similar_orders(ENUM_DIRECTIONAL_MODE mode)
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
            if(other_trades_type>=2) // if it is a pending order, break
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
  }*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void cleanup_risky_pending_orders(string instrument) // deletes pending orders of the entire account (no matter which EA/magic number) where the single currency of the market order would be the same direction of the single currency in the pending order
  { 
    int digits=(int)MarketInfo(instrument,MODE_DIGITS);
    static int last_trades_count=0;
    int trades_count=count_orders(ORDER_SET_MARKET,-1,MODE_TRADES,OrdersTotal());
    if(last_trades_count<trades_count) // true if a limit order gets triggered and becomes a market order
      {
        bool newest_ticket_selected=OrderSelect(last_order_ticket(ORDER_SET_MARKET,true),SELECT_BY_TICKET);
        if(newest_ticket_selected)
          {
            int market_trades_direction=OrderType(); // i already know it is a market order ticket because the previous line ensures that only a market trade is selected
            if(market_trades_direction==OP_BUY && compare_doubles(OrderTakeProfit(),OrderStopLoss(),digits)>=0) return; // if the market trade is at breakeven or higher, there is no reason to cleanup pending orders because the risk is reduced
            else if(market_trades_direction==OP_SELL && compare_doubles(OrderStopLoss(),OrderTakeProfit(),digits)>=0) return;
            else
              {
                string market_trades_symbol=OrderSymbol();
                string market_trades_1st_ccy=StringSubstr(market_trades_symbol,0,3); // this only works if the first 3 characters of the symbol is a currency
                string market_trades_2nd_ccy=StringSubstr(market_trades_symbol,3,3); // this only works if the next 3 characters of the symbol is a currency
                for(int i=OrdersTotal()-1;i>=0;i--)
                  {
                    if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
                      {
                        int pending_orders_direction=OrderType();
                        if(pending_orders_direction<=1) // if it is a market order, move on to the next iteration
                          {
                            break;
                          }
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
      }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_DIRECTION_BIAS signal_check_risky_market_trade(string instrument,ENUM_DIRECTION_BIAS current_bias,int _max_risk_trades)
  {
    ENUM_DIRECTION_BIAS bias=DIRECTION_BIAS_IGNORE;
    if(pullback_percent==0 || pullback_percent==NULL)
      {
        int trades_count=count_orders(ORDER_SET_MARKET,-1,MODE_TRADES,OrdersTotal());
        if(trades_count>0)
          {
            int digits=(int)MarketInfo(instrument,MODE_DIGITS);
            string potential_1st_ccy=StringSubstr(instrument,0,3); // this only works if the first 3 characters of the symbol is a currency
            string potential_2nd_ccy=StringSubstr(instrument,3,3); // this only works if the next 3 characters of the symbol is a currency
            string potential_long_ccy,potential_short_ccy;   
            if(current_bias==DIRECTION_BIAS_BUY)
              {
                potential_long_ccy=potential_1st_ccy;
                potential_short_ccy=potential_2nd_ccy;
              }
            else if(current_bias==DIRECTION_BIAS_SELL)
              {
                potential_long_ccy=potential_2nd_ccy;
                potential_short_ccy=potential_1st_ccy; 
              }
            else 
              { 
                print_and_email("Error","signal_check_risky_market_trade: Coding Error: only BUY and SELL biases are allowed.");
                return DIRECTION_BIAS_NEUTRALIZE;
              }
            int count=0;
            for(int i=OrdersTotal()-1;i>=0;i--)
              {
                if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
                  {
                    int trades_direction=OrderType();
                    if(trades_direction<=1)
                      {
                        string trades_symbol=OrderSymbol();
                        string trades_1st_ccy=StringSubstr(trades_symbol,0,3);
                        string trades_2nd_ccy=StringSubstr(trades_symbol,3,3);
                        string trades_long_ccy,trades_short_ccy;
                        if(trades_direction==OP_BUY)
                          {
                            if(compare_doubles(OrderTakeProfit(),OrderStopLoss(),digits)>=0) break; // if the market trade is at breakeven or higher, there is no reason to analyze this iteration any further
                            trades_long_ccy=trades_1st_ccy;
                            trades_short_ccy=trades_2nd_ccy;
                          }
                        else if(trades_direction==OP_SELL)
                          {
                            if(compare_doubles(OrderTakeProfit(),OrderStopLoss(),digits)<=0) break; // if the market trade is at breakeven or higher, there is no reason to analyze this iteration any further
                            trades_long_ccy=trades_2nd_ccy;
                            trades_short_ccy=trades_1st_ccy;
                          }                
                        if(trades_long_ccy==potential_long_ccy) 
                          {
                            count++;
                          }
                        if(trades_short_ccy==potential_short_ccy) 
                          {
                            count++;
                          }
                      }
                  }
              }
            if(count<_max_risk_trades) 
              {
                bias=DIRECTION_BIAS_IGNORE;
              }  
            else 
              {
                bias=DIRECTION_BIAS_NEUTRALIZE;
                if(current_bias==DIRECTION_BIAS_BUY) print_and_email("Info","A "+instrument+" long trade was prevented from entering to prevent too much risk in a single currency.");
                else if(current_bias==DIRECTION_BIAS_SELL) print_and_email("Info","A "+instrument+" short trade was prevented from entering to prevent too much risk in a single currency.");
                else print_and_email("Info","A "+instrument+" trade that was not a buy or sell signal was prevented from entering to prevent too much risk in a single currency.");
              }
          }
      }
    return bias;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool last_x_trades_were_loss(int x_trades,int magic=-1) // 2 trades max
  {
    int ticket=0;
    int order_count=OrdersHistoryTotal();
    if(order_count>1)
      { 
        datetime order_time=-1;
        int      count=0;
        for(int i=order_count-1;i>=0;i--) // iterate from the last in the index to the first
          {
            if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) 
              {
                if(OrderMagicNumber()==magic || magic==-1)
                  {
                    if(OrderType()<=1 && OrderCloseTime()>order_time) 
                      {
                        order_time=OrderCloseTime();
                      }                  
                  }
              }
          }
        if(order_time==-1) return false; // if nothing was found, return the default 0 valued ticket to prevent another loop
        for(int i=OrdersHistoryTotal()-1;i>=0;i--) // get the OrdersTotal again and then iterate from the last in the index to the first
          {
            if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
              {
                if(OrderMagicNumber()==magic || magic==-1)
                  {
                    if(OrderType()<=1 && OrderCloseTime()==order_time) 
                      {
                        count++;
                        ticket=OrderTicket();
                      }
                  }
              }
          }
        if(count>1) print_and_email("Warning","There are "+IntegerToString(count)+" market trades or limit orders that have the same time and this situation may result in a single currency in two different currency pairs being traded in the same direction.");
        if(ticket>0)
          {
            int second_ticket=0;
            OrderSelect(ticket,SELECT_BY_TICKET,MODE_HISTORY);
            if(OrderProfit()>=0) return false;
            else
              {
                if(x_trades==1) return true;
                int seconds_between_orders=-1;
                for(int i=order_count-1;i>=0;i--) // iterate from the last in the index to the first
                  {
                    if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) 
                      {
                        if(OrderMagicNumber()==magic || magic==-1)
                          {
                            if(OrderType()<=1 && OrderCloseTime()<order_time) 
                              {
                                
                                int time_between_orders=int(order_time-OrderCloseTime());
                                if(time_between_orders<seconds_between_orders || seconds_between_orders==-1) 
                                  {
                                    seconds_between_orders=time_between_orders;
                                    second_ticket=OrderTicket();
                                  }
                              }
                          }
                      }
                  }
              }
            if(second_ticket>0) 
              {
                OrderSelect(second_ticket,SELECT_BY_TICKET,MODE_HISTORY);
                if(OrderProfit()>=0) return false;
                else 
                  {
                    //Print("SECOND TICKET PROFIT: ",OrderProfit());
                    return true;
                  }
              }
            else return false;
          }    
      }
    else return false;
    return false; 
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int last_order_ticket(ENUM_ORDER_SET order_set,bool most_recent) 
  {
    datetime  order_time=-1;
    int       count=0;
    int       ticket=0;
    int       order_count=OrdersTotal();
    if(order_count>1)
      {
        for(int i=order_count-1;i>=0;i--) // iterate from the last in the index to the first
          {
            if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) 
              {
                bool correct_order=false;
                bool correct_time=false;
                if(order_set==ORDER_SET_MARKET && OrderType()<=1) correct_order=true;
                else if(order_set==ORDER_SET_LIMIT && OrderType()>=2) correct_order=true;
                if(most_recent==true) correct_time=OrderOpenTime()>order_time;
                else // where the most_recent boolean parameter is set to false (meaning, the oldest orders should be selected)
                  {
                    if(i==order_count-1) order_time=OrderOpenTime(); // this line is here because you can't leave order_time as the default -1 value or else correct_time will never be true for any of the iterations
                    correct_time=OrderOpenTime()<order_time;
                  }
                if(correct_order && correct_time) 
                  {
                    order_time=OrderOpenTime();
                  }
              }
          }
        if(order_time==-1) return(ticket); // if nothing was found, return the default 0 valued ticket to prevent another loop
        for(int i=OrdersTotal()-1;i>=0;i--) // get the OrdersTotal again and then iterate from the last in the index to the first
          {
            if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
              {
                bool correct_order=false;
                if(order_set==ORDER_SET_MARKET && OrderType()<=1) correct_order=true;
                else if(order_set==ORDER_SET_LIMIT && OrderType()>=2) correct_order=true; // 2 and 3 are both limit orders
                if(correct_order && OrderOpenTime()==order_time) 
                  {
                    count++;
                    ticket=OrderTicket();
                  }
              }
           }
         if(count>1) print_and_email("Warning","There are "+IntegerToString(count)+" market trades or limit orders that have the same time and this situation may result in a single currency in two different currency pairs being traded in the same direction."); // TODO: create an email alert       
      }
    else if(order_count==1)
      {
        if(OrderSelect(0,SELECT_BY_POS,MODE_TRADES)) 
          {
            bool correct_order=false;
            bool correct_time=false;
            if(order_set==ORDER_SET_MARKET && OrderType()<=1) correct_order=true;
            else if(order_set==ORDER_SET_LIMIT && OrderType()>=2) correct_order=true;
            if(correct_order) 
              {     
                ticket=OrderTicket();
              }
          }
      }
    else ticket=0;
    return(ticket); 
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+