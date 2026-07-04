//+------------------------------------------------------------------+
//|                                                    STX_Edge.mq5  |
//|                        STX Edge - Multi-TF Pattern Indicator      |
//|                        Converted from Pine Script v6              |
//+------------------------------------------------------------------+
#property copyright "STX Edge"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//--- Input parameters
input bool   InpSoftStart         = false; // SOFT START
input int    InpTPMultiplier      = 8;     // TP Multiplier
input int    InpSetupLookback     = 5;     // Setup Lookback
input double InpPipTarget         = 40.0;  // Pip Target
input int    InpLaolDeleteDelay   = 2;     // LAOL Delete Delay
input bool   InpShowFinalEntry    = true;  // Show Final Entry
input bool   InpShowFinalS1S4     = true;  // Show Final S1-S4
input bool   InpShowFinalIntraEst = true;  // Show Final Intra EST
input bool   InpShowFinalIntraEM  = true;  // Show Final Intra EM
input bool   InpShowFinalIntraLV  = false; // Show Final Intra LV
input bool   InpShowFinalIntraNeg = true;  // Show Final Intra NEG
input bool   InpFinalEntryMultiLaol = false; // Final Entry Multi LAOL
input bool   InpShowIntraEstRetest  = true;  // Show Intra EST Retest
input bool   InpShowIntraEMForming  = true;  // Show Intra EM Forming
input bool   InpShowIntraLVAligned  = false; // Show Intra LV Aligned
input bool   InpShowIntraNegation   = true;  // Show Intra Negation
input bool   InpShowHCSBoxes        = true;  // Show HCS Boxes
input bool   InpShowSetupsS1S4      = true;  // Show Setups S1-S4

//--- Constants
#define TF_COUNT          25
#define ENTRY_MIN_IDX     0
#define ENTRY_MAX_IDX     4
#define SCALP_MIN_IDX     5
#define SCALP_MAX_IDX     15
#define INTRA_MIN_IDX     16
#define INTRA_MAX_IDX     24
#define UNRETESTED_BORDER_TRANS 100
#define MAX_BOXES_PER_TF  50
#define MAX_LAOL_LINES    100
#define MAX_HCS_BOXES     50
#define MAX_RR_BOXES      50
#define MAX_XLAOL         100

//--- TF minutes array
const int TF_MINUTES[TF_COUNT] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,20,30,35,40,45,50,55,60,90,100};

//--- Enumerations
enum ENUM_TF_CATEGORY { CAT_ENTRY, CAT_SCALP, CAT_INTRA, CAT_NONE };
enum ENUM_BOX_STATE { STATE_FORMING, STATE_ESTABLISHED, STATE_EST_RETEST, STATE_RESPECTED, STATE_FORMING_FRESH };

//--- Color constants (ARGB format: 0xAARRGGBB)
// In MQL5 ARGB: Alpha 0=opaque, 255=transparent
// Pine Script transparency: 0=opaque, 100=transparent
// Conversion: MQL5_alpha = PineTransparency * 255 / 100
const color CLR_ENTRY_BOX       = C'13,13,242';    // blue
const color CLR_ENTRY_BORDER    = C'13,13,242';    // blue
const color CLR_SCALP_BOX       = C'13,242,13';    // green
const color CLR_SCALP_BORDER    = C'13,242,13';    // green
const color CLR_INTRA_BOX       = C'242,13,13';    // red
const color CLR_INTRA_BORDER    = C'242,13,13';    // red
const color CLR_HCS_BEAR_BG     = C'255,165,0';    // orange
const color CLR_HCS_BEAR_BORDER = C'255,165,0';    // orange
const color CLR_HCS_BULL_BG     = C'33,150,243';   // #2196F3
const color CLR_HCS_BULL_BORDER = C'33,150,243';   // #2196F3
const color CLR_RR_SL           = C'255,0,0';      // red
const color CLR_RR_TP           = C'0,128,0';      // green
const color CLR_LAOL_ENTRY      = C'0,0,255';      // blue
const color CLR_LAOL_SCALP      = C'0,128,0';      // green

//--- Struct definitions
struct SeqState
{
   int   step;
   double level;
   double body;
   datetime start_time;
   void Reset() { step=0; level=0; body=0; start_time=0; }
};

struct TrackedBox
{
   string   direction;
   int      state;        // ENUM_BOX_STATE
   double   top_val;
   double   bottom_val;
   double   original_top;
   double   original_bottom;
   datetime creation_time;
   datetime protection_end_time;
   string   pattern_text;
   string   base_pattern;
   string   timeframe;
   string   obj_name;
   bool     has_est_retest;
   string   retest_type;
   bool     protection_active;
   int      hcs_count;
   color    box_clr;
   color    border_clr;
   bool     has_been_retested;
   bool     is_intra;
   double   est_wick_high;
   double   est_wick_low;
   bool     completed_est_retest;
   bool     is_em_forming;
   bool     just_established;
   uchar    box_alpha;
   uchar    border_alpha;
   bool     active;
};

struct LaolLineData
{
   string   obj_name;
   string   label_name;
   double   level;
   string   tf_labels;
   int      creation_bar;
   bool     is_bear;
   bool     is_broken;
   int      break_bar;
   int      tf_count;
   bool     has_entry;
   bool     has_scalp;
   bool     has_intra;
   bool     active;
};

struct LastValidInfo
{
   string   pattern_text;
   string   original_text;
   double   level;
   datetime est_time;
   string   direction;
   bool     is_broken;
   void Reset() { pattern_text="None"; original_text="None"; level=0; est_time=0; direction=""; is_broken=false; }
};

struct HcsBoxData
{
   string   obj_name;
   double   top_val;
   double   bottom_val;
   int      creation_bar;
   string   tf_label;
   string   direction;
   bool     is_broken;
   bool     active;
};

struct RrBoxSet
{
   string   sl_obj_name;
   string   tp_obj_name;
   string   pip_obj_name;
   string   direction;
   double   sl_level;
   int      creation_bar;
   bool     active;
};

struct XlaolData
{
   string   line_name;
   string   label_name;
   double   level;
   bool     is_bear;
   string   category;
   int      offset;
   bool     active;
};

//--- Global arrays
TrackedBox  g_tf_boxes[TF_COUNT][MAX_BOXES_PER_TF];
int         g_tf_box_count[TF_COUNT];

LaolLineData g_bear_laol[MAX_LAOL_LINES];
LaolLineData g_bull_laol[MAX_LAOL_LINES];
LaolLineData g_bear_scalp_laol[MAX_LAOL_LINES];
LaolLineData g_bull_scalp_laol[MAX_LAOL_LINES];
LaolLineData g_bear_intra_laol[MAX_LAOL_LINES];
LaolLineData g_bull_intra_laol[MAX_LAOL_LINES];
int g_bear_laol_count, g_bull_laol_count;
int g_bear_scalp_laol_count, g_bull_scalp_laol_count;
int g_bear_intra_laol_count, g_bull_intra_laol_count;

HcsBoxData g_hcs_boxes_bear[MAX_HCS_BOXES];
HcsBoxData g_hcs_boxes_bull[MAX_HCS_BOXES];
int g_hcs_bear_count, g_hcs_bull_count;

RrBoxSet g_rr_boxes_bear[MAX_RR_BOXES];
RrBoxSet g_rr_boxes_bull[MAX_RR_BOXES];
int g_rr_bear_count, g_rr_bull_count;

XlaolData g_xlaol[MAX_XLAOL];
int g_xlaol_count;

//--- Pattern detection arrays
bool arr_fu_bear[TF_COUNT], arr_fu_bull[TF_COUNT];
bool arr_sn_bear[TF_COUNT], arr_sn_bull[TF_COUNT];
bool arr_first_bear[TF_COUNT], arr_first_bull[TF_COUNT];
bool arr_second_bear[TF_COUNT], arr_second_bull[TF_COUNT];
bool arr_third_bear[TF_COUNT], arr_third_bull[TF_COUNT];
bool arr_laol_bear[TF_COUNT], arr_laol_bull[TF_COUNT];
bool arr_laol_first_bear[TF_COUNT], arr_laol_first_bull[TF_COUNT];
bool arr_laol_candle_bear[TF_COUNT], arr_laol_candle_bull[TF_COUNT];

//--- TF data arrays
double arr_tf_h[TF_COUNT], arr_tf_l[TF_COUNT];
double arr_tf_bt[TF_COUNT], arr_tf_bb[TF_COUNT];
datetime arr_tf_t[TF_COUNT];
bool arr_tf_conf[TF_COUNT];

//--- Retest arrays
bool arr_bear_retesting[TF_COUNT], arr_bull_retesting[TF_COUNT];
bool arr_bear_est_retest[TF_COUNT], arr_bull_est_retest[TF_COUNT];
bool arr_bear_est_retest_VALID[TF_COUNT], arr_bull_est_retest_VALID[TF_COUNT];
string arr_bear_retest_pattern[TF_COUNT], arr_bull_retest_pattern[TF_COUNT];
double arr_bear_retest_level[TF_COUNT], arr_bull_retest_level[TF_COUNT];

//--- HCS arrays
bool arr_bear_hcs[TF_COUNT], arr_bull_hcs[TF_COUNT];
bool arr_bear_hcs_forming[TF_COUNT], arr_bull_hcs_forming[TF_COUNT];
bool arr_bear_hcs_broken[TF_COUNT], arr_bull_hcs_broken[TF_COUNT];
bool arr_bear_hcs_retesting[TF_COUNT], arr_bull_hcs_retesting[TF_COUNT];
datetime arr_last_bear_hcs_time[TF_COUNT], arr_last_bull_hcs_time[TF_COUNT];

//--- Third pattern tracking
int arr_bear_third_step[TF_COUNT], arr_bull_third_step[TF_COUNT];
double arr_bear_third_ref_h[TF_COUNT], arr_bear_third_ref_l[TF_COUNT];
double arr_bull_third_ref_h[TF_COUNT], arr_bull_third_ref_l[TF_COUNT];
datetime arr_bear_third_ref_time[TF_COUNT], arr_bull_third_ref_time[TF_COUNT];

//--- LAOL step tracking
int arr_bear_laol_step[TF_COUNT], arr_bull_laol_step[TF_COUNT];
double arr_bear_laol_ref_h[TF_COUNT], arr_bear_laol_ref_l[TF_COUNT];
double arr_bull_laol_ref_h[TF_COUNT], arr_bull_laol_ref_l[TF_COUNT];
datetime arr_bear_laol_ref_time[TF_COUNT], arr_bull_laol_ref_time[TF_COUNT];

//--- Sequence states
SeqState arr_bear_seq[TF_COUNT], arr_bull_seq[TF_COUNT];

//--- TF label/category arrays
string TF_LABELS[TF_COUNT];
string TF_CATEGORIES[TF_COUNT];
string TFS[TF_COUNT];

//--- Last Valid Info
LastValidInfo entry_bear_lv, entry_bull_lv;
LastValidInfo scalp_bear_lv, scalp_bull_lv;
LastValidInfo intra_bear_lv, intra_bull_lv;

//--- Global state variables
datetime last_bear_laol_break_time, last_bull_laol_break_time;
string last_bear_laol_tf, last_bull_laol_tf;
datetime last_bear_scalp_laol_break_time, last_bull_scalp_laol_break_time;
string last_bear_scalp_laol_tf, last_bull_scalp_laol_tf;
datetime last_bear_intra_laol_break_time, last_bull_intra_laol_break_time;
string last_bear_intra_laol_tf, last_bull_intra_laol_tf;
int final_entry_bear_setup_bar, final_entry_bull_setup_bar;
string final_entry_bear_pattern, final_entry_bull_pattern;
int last_bear_forming_bar, last_bear_confirmed_bar;
int last_bull_forming_bar, last_bull_confirmed_bar;
bool intra_bear_negating, intra_bull_negating;
string intra_bear_negating_pattern, intra_bull_negating_pattern;
double pip_value;
int g_obj_counter;

//--- Forming RR state
string bear_forming_rr_sl_name, bear_forming_rr_tp_name, bear_forming_rr_pip_name;
int bear_forming_rr_bar;
string bear_forming_type, bear_forming_type_prev;
string bull_forming_rr_sl_name, bull_forming_rr_tp_name, bull_forming_rr_pip_name;
int bull_forming_rr_bar;
string bull_forming_type, bull_forming_type_prev;

//+------------------------------------------------------------------+
//| Helper: Get ENUM_TIMEFRAMES from minutes                          |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetTimeframe(int minutes)
{
   switch(minutes)
   {
      case 1:   return PERIOD_M1;
      case 2:   return PERIOD_M2;
      case 3:   return PERIOD_M3;
      case 4:   return PERIOD_M4;
      case 5:   return PERIOD_M5;
      case 6:   return PERIOD_M6;
      case 7:   return PERIOD_M6;   // M7 -> M6
      case 8:   return PERIOD_M6;   // M8 -> M6
      case 9:   return PERIOD_M10;  // M9 -> M10
      case 10:  return PERIOD_M10;
      case 11:  return PERIOD_M10;  // M11 -> M10
      case 12:  return PERIOD_M12;
      case 13:  return PERIOD_M12;  // M13 -> M12
      case 14:  return PERIOD_M15;  // M14 -> M15
      case 15:  return PERIOD_M15;
      case 20:  return PERIOD_M20;
      case 30:  return PERIOD_M30;
      case 35:  return PERIOD_M30;  // M35 -> M30
      case 40:  return PERIOD_M30;  // M40 -> M30
      case 45:  return PERIOD_H1;   // M45 -> H1
      case 50:  return PERIOD_H1;   // M50 -> H1
      case 55:  return PERIOD_H1;   // M55 -> H1
      case 60:  return PERIOD_H1;
      case 90:  return PERIOD_H1;   // M90 -> H1
      case 100: return PERIOD_H2;   // M100 -> H2
      default:  return PERIOD_M1;
   }
}

//+------------------------------------------------------------------+
//| Helper: Get category from TF index                                |
//+------------------------------------------------------------------+
ENUM_TF_CATEGORY GetCategory(int idx)
{
   if(idx >= ENTRY_MIN_IDX && idx <= ENTRY_MAX_IDX) return CAT_ENTRY;
   if(idx >= SCALP_MIN_IDX && idx <= SCALP_MAX_IDX) return CAT_SCALP;
   if(idx >= INTRA_MIN_IDX && idx <= INTRA_MAX_IDX) return CAT_INTRA;
   return CAT_NONE;
}

string GetCategoryStr(int idx)
{
   ENUM_TF_CATEGORY cat = GetCategory(idx);
   if(cat == CAT_ENTRY) return "ENTRY";
   if(cat == CAT_SCALP) return "SCALP";
   if(cat == CAT_INTRA) return "INTRA";
   return "NONE";
}

string GetCategoryFromMinutes(int minutes)
{
   if(minutes >= 1 && minutes <= 5) return "ENTRY";
   if(minutes >= 6 && minutes <= 20) return "SCALP";
   if(minutes >= 30 && minutes <= 120) return "INTRA";
   return "NONE";
}

//+------------------------------------------------------------------+
//| Helper: Format TF label                                           |
//+------------------------------------------------------------------+
string FormatTFLabel(int minutes)
{
   if(minutes >= 60 && minutes % 60 == 0)
      return IntegerToString(minutes/60) + "H";
   return IntegerToString(minutes) + "m";
}

//+------------------------------------------------------------------+
//| Helper: Check if TF is entry category                             |
//+------------------------------------------------------------------+
bool IsEntry(int minutes)
{
   return minutes >= 1 && minutes <= 5;
}

//+------------------------------------------------------------------+
//| Helper: Generate unique object name                               |
//+------------------------------------------------------------------+
string GenObjName(string prefix)
{
   g_obj_counter++;
   return "STX_" + prefix + "_" + IntegerToString(g_obj_counter) + "_" + IntegerToString(GetTickCount());
}

//+------------------------------------------------------------------+
//| Helper: Create rectangle object                                   |
//+------------------------------------------------------------------+
void CreateBox(string name, datetime time1, double price1, datetime time2, double price2,
               color clr, uchar alpha, color border_clr, uchar border_alpha,
               int border_width, ENUM_LINE_STYLE border_style, string text="")
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price1, time2, price2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border_clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, border_style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, border_width);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   // Set colors with transparency using ARGB
   long fill_argb = ((long)(255-alpha) << 24) | ((long)((clr & 0xFF0000)>>16)) | ((long)(clr & 0x00FF00)) | ((long)((clr & 0x0000FF)<<16));
   long brd_argb = ((long)(255-border_alpha) << 24) | ((long)((border_clr & 0xFF0000)>>16)) | ((long)(border_clr & 0x00FF00)) | ((long)((border_clr & 0x0000FF)<<16));
   ObjectSetInteger(0, name, OBJPROP_COLOR, border_clr);
   // Use native color with alpha channel
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Helper: Create zone box with proper colors                        |
//+------------------------------------------------------------------+
void CreateZoneBox(string name, datetime time1, double price1, datetime time2, double price2,
                   color fill_clr, uchar fill_trans, color border_clr, uchar border_trans,
                   ENUM_LINE_STYLE border_style, int border_width, string text="")
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price1, time2, price2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border_clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, border_style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, border_width);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   // Text label for box
   if(text != "")
   {
      string lbl_name = name + "_txt";
      if(ObjectFind(0, lbl_name) >= 0) ObjectDelete(0, lbl_name);
      ObjectCreate(0, lbl_name, OBJ_TEXT, 0, time1, price1);
      ObjectSetString(0, lbl_name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, lbl_name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, lbl_name, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, lbl_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, lbl_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lbl_name, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
//| Helper: Create trend line                                         |
//+------------------------------------------------------------------+
void CreateLine(string name, datetime time1, double price1, datetime time2, double price2,
                color clr, int width, ENUM_LINE_STYLE style)
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Helper: Create text label on chart                                |
//+------------------------------------------------------------------+
void CreateTextLabel(string name, datetime time1, double price1, string text,
                     color clr, int fontsize=7, ENUM_ANCHOR_POINT anchor=ANCHOR_LEFT)
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TEXT, 0, time1, price1);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontsize);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Helper: Check if string contains substring                        |
//+------------------------------------------------------------------+
bool StrContains(const string &str, const string &sub)
{
   return StringFind(str, sub) >= 0;
}

//+------------------------------------------------------------------+
//| Helper: Has both wicks                                            |
//+------------------------------------------------------------------+
bool HasBothWicks(double o, double h, double l, double c)
{
   return MathMax(o,c) < h && MathMin(o,c) > l;
}

//+------------------------------------------------------------------+
//| Helper: Is inside bar                                             |
//+------------------------------------------------------------------+
bool IsInsideBar(double p_h, double p_l, double p_h1, double p_l1)
{
   return p_h < p_h1 && p_l > p_l1;
}

//+------------------------------------------------------------------+
//| Helper: Is EM pattern                                             |
//+------------------------------------------------------------------+
bool IsEMPattern(const string &pattern)
{
   if(pattern == "") return false;
   return StrContains(pattern, "HCS") || StrContains(pattern, "Third") ||
          StrContains(pattern, "First") || StrContains(pattern, "LAOL") ||
          StrContains(pattern, "TBE") || StrContains(pattern, "[EM]");
}

//+------------------------------------------------------------------+
//| Helper: Is FU pattern (FU/SN without EM modifiers)                |
//+------------------------------------------------------------------+
bool IsFUPattern(const string &pattern)
{
   if(pattern == "") return false;
   bool has_fu = StrContains(pattern, "FU");
   bool has_sn = StrContains(pattern, "SN");
   bool has_em = StrContains(pattern, "HCS") || StrContains(pattern, "Third") ||
                 StrContains(pattern, "First") || StrContains(pattern, "LAOL") ||
                 StrContains(pattern, "TBE");
   return (has_fu || has_sn) && !has_em;
}

//+------------------------------------------------------------------+
//| Helper: Build pattern string                                      |
//+------------------------------------------------------------------+
string BuildPatternStr(bool is_bear, bool third, bool first, bool laol,
                       bool sn, bool sn_dbl, bool fu, bool tbe, bool hcs, bool hcs_forming)
{
   string result = "";
   if(third)
      result = "X3 Third";
   if(first)
      result = (result == "") ? "X3 First" : result + " + X3 First";
   if(laol)
      result = (result == "") ? "LAOL Neg" : result + " + LAOL Neg";
   if(sn)
   {
      string sn_txt = sn_dbl ? "SN [EM]" : "SN";
      result = (result == "") ? sn_txt : result + " + " + sn_txt;
   }
   if(fu)
   {
      string fu_txt = tbe ? "FU [TBE]" : "FU";
      result = (result == "") ? fu_txt : result + " + " + fu_txt;
   }
   if(hcs)
      result = (result == "") ? "[HCS]" : result + " + [HCS]";
   else if(hcs_forming)
      result = (result == "") ? "[HCS]" : result + " + [HCS]";
   
   if(result != "")
      return (is_bear ? "Bear " : "Bull ") + result;
   return "";
}

//+------------------------------------------------------------------+
//| Helper: Time ago string                                           |
//+------------------------------------------------------------------+
string TimeAgo(datetime past_time)
{
   if(past_time == 0) return "";
   long elapsed_ms = (long)(TimeCurrent() - past_time) * 1000;
   long elapsed_min = elapsed_ms / 60000;
   if(elapsed_min < 1) return " (<1m ago)";
   if(elapsed_min < 60) return " (" + IntegerToString(elapsed_min) + "m ago)";
   if(elapsed_min < 1440)
   {
      long hours = elapsed_min / 60;
      long mins = elapsed_min % 60;
      string s = " (" + IntegerToString(hours) + "h";
      if(mins > 0) s += IntegerToString(mins) + "m";
      return s + " ago)";
   }
   long days = elapsed_min / 1440;
   return " (" + IntegerToString(days) + "d ago)";
}

//+------------------------------------------------------------------+
//| Get future time (bars ahead)                                      |
//+------------------------------------------------------------------+
datetime GetFutureTime(int bars_ahead)
{
   datetime current_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   int period_seconds = PeriodSeconds(PERIOD_CURRENT);
   return current_time + bars_ahead * period_seconds;
}

//+------------------------------------------------------------------+
//| Get bar index (bars from current)                                 |
//+------------------------------------------------------------------+
int GetBarIndex()
{
   return iBars(_Symbol, PERIOD_CURRENT) - 1;
}

//+------------------------------------------------------------------+
//| Update TBE sequence                                               |
//+------------------------------------------------------------------+
bool UpdateSeq(SeqState &seq, bool is_fu, bool is_x3, bool counter_fu, bool counter_x3,
               double level, double body, int tf_minutes, bool confirmed, bool is_bear,
               double p_h, double p_l)
{
   if(!confirmed) return false;
   
   int tf_seconds = tf_minutes * 60;
   long candles_since = 0;
   if(seq.start_time > 0)
      candles_since = ((long)TimeCurrent() - (long)seq.start_time) / tf_seconds;
   
   if(seq.step > 0 && seq.step < 5 && candles_since > 5)
   {
      seq.Reset();
   }
   
   bool is_valid = false;
   
   if(seq.step == 5)
   {
      seq.Reset();
   }
   else if(seq.step == 4)
   {
      bool broke_level = is_bear ? (p_h > seq.level) : (p_l < seq.level);
      if(broke_level)
         seq.Reset();
      else if(is_fu)
      {
         seq.step = 5;
         is_valid = true;
      }
   }
   else if(seq.step == 3)
   {
      bool broke_level = is_bear ? (p_h > seq.level) : (p_l < seq.level);
      bool in_zone = is_bear ? (p_h > seq.body && p_h < seq.level) : (p_l < seq.body && p_l > seq.level);
      if(broke_level)
         seq.Reset();
      else if(in_zone)
         seq.step = 4;
   }
   else if(seq.step == 2)
   {
      bool broke_level = is_bear ? (p_h > seq.level) : (p_l < seq.level);
      if(broke_level)
         seq.Reset();
      else if(counter_fu || counter_x3)
         seq.step = 3;
   }
   else if(seq.step == 1)
   {
      bool broke_level = is_bear ? (p_h > seq.level) : (p_l < seq.level);
      bool in_zone = is_bear ? (p_h >= seq.body && p_h <= seq.level) : (p_l <= seq.body && p_l >= seq.level);
      if(broke_level)
         seq.Reset();
      else if(in_zone)
         seq.step = 2;
      else
         seq.Reset();
   }
   
   if((is_fu || is_x3) && seq.step == 0)
   {
      seq.step = 1;
      seq.level = level;
      seq.body = body;
      seq.start_time = TimeCurrent();
   }
   
   return is_valid;
}

//+------------------------------------------------------------------+
//| Get MTF candle data                                               |
//+------------------------------------------------------------------+
bool GetTFData(ENUM_TIMEFRAMES tf, double &o2, double &h2, double &l2, double &c2,
               double &o1, double &h1, double &l1, double &c1,
               double &o0, double &h0, double &l0, double &c0,
               datetime &t0, bool &is_confirmed)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, 3, rates);
   if(copied < 3) return false;
   
   o0 = rates[0].open;  h0 = rates[0].high;  l0 = rates[0].low;  c0 = rates[0].close;
   o1 = rates[1].open;  h1 = rates[1].high;  l1 = rates[1].low;  c1 = rates[1].close;
   o2 = rates[2].open;  h2 = rates[2].high;  l2 = rates[2].low;  c2 = rates[2].close;
   t0 = rates[0].time;
   
   // Check if the current bar on this TF is confirmed (closed)
   // A bar is confirmed if current time >= bar_time + period
   datetime bar_end = t0 + PeriodSeconds(tf);
   is_confirmed = (TimeCurrent() >= bar_end);
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate patterns for a timeframe                                |
//+------------------------------------------------------------------+
void CalculatePatterns(int idx, double p_o2, double p_h2, double p_l2, double p_c2,
                       double p_o1, double p_h1, double p_l1, double p_c1,
                       double p_o, double p_h, double p_l, double p_c,
                       datetime p_t, bool p_conf)
{
   bool valid_data   = p_h != 0 && p_l != 0;
   bool valid_data_1 = p_h1 != 0 && p_l1 != 0;
   bool valid_data_2 = p_h2 != 0 && p_l2 != 0;
   
   bool both_sides   = valid_data   ? HasBothWicks(p_o, p_h, p_l, p_c) : false;
   bool both_sides_1 = valid_data_1 ? HasBothWicks(p_o1, p_h1, p_l1, p_c1) : false;
   
   double body_top    = valid_data ? MathMax(p_o, p_c) : 0;
   double body_bottom = valid_data ? MathMin(p_o, p_c) : 0;
   
   bool is_ib = (valid_data && valid_data_1) ? IsInsideBar(p_h, p_l, p_h1, p_l1) : false;
   
   // X3 patterns
   bool bear_x3 = valid_data && valid_data_1 && p_h > p_h1 && p_l < p_l1 && both_sides && p_c < p_o;
   bool bull_x3 = valid_data && valid_data_1 && p_h > p_h1 && p_l < p_l1 && both_sides && p_c > p_o;
   bool is_x3 = bear_x3 || bull_x3;
   
   bool bear_x3_1 = (valid_data_1 && valid_data_2) ? (p_h1 > p_h2 && p_l1 < p_l2 && both_sides_1 && p_c1 < p_o1) : false;
   bool bull_x3_1 = (valid_data_1 && valid_data_2) ? (p_h1 > p_h2 && p_l1 < p_l2 && both_sides_1 && p_c1 > p_o1) : false;
   bool is_x3_1 = bear_x3_1 || bull_x3_1;
   
   // SN patterns
   bool sn_bull = p_h > p_h1 && p_l < p_l1 && MathMax(p_o,p_c) < p_h1 && MathMin(p_o,p_c) > p_l1 && p_o < p_c;
   bool sn_bear = p_h > p_h1 && p_l < p_l1 && MathMin(p_o,p_c) > p_l1 && MathMax(p_o,p_c) < p_h1 && p_o > p_c;
   bool sn_together = (sn_bull || sn_bear) && !is_x3;
   
   bool sn_bull_candle_1 = p_h1 > p_h2 && p_l1 < p_l2 && p_c1 > p_o1 && MathMax(p_o1,p_c1) < p_h2;
   bool sn_bear_candle_1 = p_h1 > p_h2 && p_l1 < p_l2 && p_c1 < p_o1 && MathMin(p_o1,p_c1) > p_l2;
   bool sn_together_1 = (sn_bull_candle_1 || sn_bear_candle_1) && !is_x3_1;
   
   // LAOL first patterns
   bool bull_laol_first = valid_data && valid_data_1 && valid_data_2 &&
                          p_l1 == MathMin(p_o1, p_c1) && p_h1 < p_h2 && p_h < p_h1 && p_l < p_l1;
   bool bear_laol_first = valid_data && valid_data_1 && valid_data_2 &&
                          p_h1 == MathMax(p_o1, p_c1) && p_l1 > p_l2 && p_l > p_l1 && p_h > p_h1;
   
   // First EM patterns
   bool bear_first_em = (bull_x3_1 || sn_together_1) && p_h > p_h1 && p_l > p_l1;
   bool bull_first_em = (bear_x3_1 || sn_together_1) && p_l < p_l1 && p_h < p_h1;
   
   // LAOL candle (inside bar)
   bool bear_laol_candle = is_ib;
   bool bull_laol_candle = is_ib;
   
   // FU patterns
   bool fu_bear_em = valid_data && valid_data_1 && p_h > p_h1 && p_c < p_h1 && p_c > p_l1 && !is_x3 && !sn_together;
   bool fu_bull_em = valid_data && valid_data_1 && p_l < p_l1 && p_c > p_l1 && p_c < p_h1 && !is_x3 && !sn_together;
   
   // Store results
   arr_fu_bear[idx] = fu_bear_em;
   arr_fu_bull[idx] = fu_bull_em;
   arr_sn_bear[idx] = sn_bear;
   arr_sn_bull[idx] = sn_bull;
   arr_first_bear[idx] = bear_first_em;
   arr_first_bull[idx] = bull_first_em;
   arr_laol_bear[idx] = bear_laol_first;
   arr_laol_bull[idx] = bull_laol_first;
   arr_laol_first_bear[idx] = bear_laol_first;
   arr_laol_first_bull[idx] = bull_laol_first;
   arr_tf_h[idx] = p_h;
   arr_tf_l[idx] = p_l;
   arr_tf_bt[idx] = body_top;
   arr_tf_bb[idx] = body_bottom;
   arr_tf_t[idx] = p_t;
   arr_tf_conf[idx] = p_conf;
   arr_laol_candle_bear[idx] = bear_laol_candle;
   arr_laol_candle_bull[idx] = bull_laol_candle;
}

//+------------------------------------------------------------------+
//| LAOL line management: Add or merge                                |
//+------------------------------------------------------------------+
void AddOrMergeLaolLine(LaolLineData &lines[], int &count, double level,
                        string tf_label, bool is_bear, string category)
{
   double tolerance = _Point * 20; // mintick*2
   bool merged = false;
   bool found_broken = false;
   
   for(int i = 0; i < count; i++)
   {
      if(!lines[i].active) continue;
      if(MathAbs(lines[i].level - level) < tolerance)
      {
         if(lines[i].is_broken)
         {
            found_broken = true;
            break;
         }
         if(!StrContains(lines[i].tf_labels, tf_label))
         {
            lines[i].tf_labels = lines[i].tf_labels + "," + tf_label;
            lines[i].tf_count++;
            if(category == "INTRA") lines[i].has_intra = true;
            else if(category == "SCALP") lines[i].has_scalp = true;
            else lines[i].has_entry = true;
         }
         merged = true;
         break;
      }
   }
   
   if(!merged && !found_broken && count < MAX_LAOL_LINES)
   {
      int idx = count;
      lines[idx].level = level;
      lines[idx].tf_labels = tf_label;
      lines[idx].creation_bar = GetBarIndex();
      lines[idx].is_bear = is_bear;
      lines[idx].tf_count = 1;
      lines[idx].has_entry = (category == "ENTRY");
      lines[idx].has_scalp = (category == "SCALP");
      lines[idx].has_intra = (category == "INTRA");
      lines[idx].is_broken = false;
      lines[idx].break_bar = 0;
      lines[idx].active = true;
      lines[idx].obj_name = "";
      lines[idx].label_name = "";
      count++;
   }
}

//+------------------------------------------------------------------+
//| LAOL line management: Update (check breaks)                       |
//+------------------------------------------------------------------+
void UpdateLaolLines(LaolLineData &lines[], int &count, bool is_bear, double current_price,
                     datetime &break_time, string &break_tf,
                     datetime &intra_break_time, string &intra_break_tf,
                     datetime &scalp_break_time, string &scalp_break_tf)
{
   break_time = 0; break_tf = "";
   intra_break_time = 0; intra_break_tf = "";
   scalp_break_time = 0; scalp_break_tf = "";
   
   int bar_idx = GetBarIndex();
   
   for(int i = count - 1; i >= 0; i--)
   {
      if(!lines[i].active) continue;
      
      bool crossed = is_bear ? (current_price > lines[i].level) : (current_price < lines[i].level);
      
      if(crossed && !lines[i].is_broken)
      {
         lines[i].is_broken = true;
         lines[i].break_bar = bar_idx;
         if(lines[i].has_intra)
         {
            intra_break_time = TimeCurrent();
            intra_break_tf = lines[i].tf_labels;
         }
         else if(lines[i].has_scalp)
         {
            scalp_break_time = TimeCurrent();
            scalp_break_tf = lines[i].tf_labels;
         }
         else
         {
            break_time = TimeCurrent();
            break_tf = lines[i].tf_labels;
         }
      }
      
      if(lines[i].is_broken && bar_idx >= lines[i].break_bar + InpLaolDeleteDelay)
      {
         // Delete visual objects
         if(lines[i].obj_name != "" && ObjectFind(0, lines[i].obj_name) >= 0)
            ObjectDelete(0, lines[i].obj_name);
         if(lines[i].label_name != "" && ObjectFind(0, lines[i].label_name) >= 0)
            ObjectDelete(0, lines[i].label_name);
         // Remove from array by shifting
         for(int j = i; j < count - 1; j++)
            lines[j] = lines[j+1];
         count--;
      }
   }
}

//+------------------------------------------------------------------+
//| LAOL: Get broken level (recent)                                   |
//+------------------------------------------------------------------+
double GetBrokenLaolRecent(LaolLineData &lines[], int count, bool require_multi, int lookback=5)
{
   int bar_idx = GetBarIndex();
   for(int i = 0; i < count; i++)
   {
      if(!lines[i].active) continue;
      if(lines[i].is_broken && (bar_idx - lines[i].break_bar) <= lookback)
      {
         if(!require_multi || lines[i].tf_count >= 2)
            return lines[i].level;
      }
   }
   return 0; // 0 means not found (equivalent to na)
}

//+------------------------------------------------------------------+
//| LAOL: Merge cross category                                        |
//+------------------------------------------------------------------+
bool MergeCrossCategory(LaolLineData &entry_lines[], int entry_count,
                        LaolLineData &scalp_lines[], int scalp_count,
                        LaolLineData &intra_lines[], int intra_count,
                        double level, string tf_label, bool is_bear)
{
   double tolerance = _Point * 20;
   
   // Check intra first
   for(int i = 0; i < intra_count; i++)
   {
      if(!intra_lines[i].active) continue;
      if(MathAbs(intra_lines[i].level - level) < tolerance && !intra_lines[i].is_broken)
      {
         if(!StrContains(intra_lines[i].tf_labels, tf_label))
         {
            intra_lines[i].tf_labels = intra_lines[i].tf_labels + "," + tf_label;
            intra_lines[i].tf_count++;
         }
         return true;
      }
   }
   // Check scalp
   for(int i = 0; i < scalp_count; i++)
   {
      if(!scalp_lines[i].active) continue;
      if(MathAbs(scalp_lines[i].level - level) < tolerance && !scalp_lines[i].is_broken)
      {
         if(!StrContains(scalp_lines[i].tf_labels, tf_label))
         {
            scalp_lines[i].tf_labels = scalp_lines[i].tf_labels + "," + tf_label;
            scalp_lines[i].tf_count++;
         }
         return true;
      }
   }
   // Check entry
   for(int i = 0; i < entry_count; i++)
   {
      if(!entry_lines[i].active) continue;
      if(MathAbs(entry_lines[i].level - level) < tolerance && !entry_lines[i].is_broken)
      {
         if(!StrContains(entry_lines[i].tf_labels, tf_label))
         {
            entry_lines[i].tf_labels = entry_lines[i].tf_labels + "," + tf_label;
            entry_lines[i].tf_count++;
         }
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| LAOL: Scan LAOL in box (visual drawing)                           |
//+------------------------------------------------------------------+
void ScanLaolInBox(LaolLineData &laol_arr[], int laol_count,
                   double box_top, double box_bot, bool is_bear,
                   string laol_cat, string box_cat)
{
   color col = (laol_cat == "ENTRY") ? CLR_LAOL_ENTRY : CLR_LAOL_SCALP;
   int off = (laol_cat == "ENTRY") ? 15 : 30;
   double tol = _Point * 30;
   
   for(int i = 0; i < laol_count; i++)
   {
      if(!laol_arr[i].active) continue;
      if(laol_arr[i].is_broken) continue;
      if(laol_arr[i].level <= box_top && laol_arr[i].level >= box_bot)
      {
         // Check duplicates
         bool already = false;
         for(int j = 0; j < g_xlaol_count; j++)
         {
            if(!g_xlaol[j].active) continue;
            if(MathAbs(g_xlaol[j].level - laol_arr[i].level) < tol && g_xlaol[j].category == laol_cat)
            {
               // Update existing label text
               if(g_xlaol[j].label_name != "" && ObjectFind(0, g_xlaol[j].label_name) >= 0)
               {
                  string cur_txt = ObjectGetString(0, g_xlaol[j].label_name, OBJPROP_TEXT);
                  if(!StrContains(cur_txt, box_cat))
                  {
                     ObjectSetString(0, g_xlaol[j].label_name, OBJPROP_TEXT, cur_txt + "+" + box_cat);
                     ObjectSetInteger(0, g_xlaol[j].label_name, OBJPROP_COLOR, clrPurple);
                  }
               }
               already = true;
               break;
            }
         }
         
         if(!already && g_xlaol_count < MAX_XLAOL)
         {
            datetime t_now = iTime(_Symbol, PERIOD_CURRENT, 0);
            datetime t_end = GetFutureTime(off);
            
            string ln_name = GenObjName("XLAOL_L");
            string lb_name = GenObjName("XLAOL_B");
            
            CreateLine(ln_name, t_now, laol_arr[i].level, t_end, laol_arr[i].level,
                       col, 1, STYLE_DASH);
            
            string lbl_text = laol_cat + " LAOL [" + laol_arr[i].tf_labels + "] in " + box_cat;
            CreateTextLabel(lb_name, t_end, laol_arr[i].level, lbl_text, clrWhite, 7, ANCHOR_LEFT);
            
            int xi = g_xlaol_count;
            g_xlaol[xi].line_name = ln_name;
            g_xlaol[xi].label_name = lb_name;
            g_xlaol[xi].level = laol_arr[i].level;
            g_xlaol[xi].is_bear = is_bear;
            g_xlaol[xi].category = laol_cat;
            g_xlaol[xi].offset = off;
            g_xlaol[xi].active = true;
            g_xlaol_count++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage TF boxes (zone state machine)                              |
//+------------------------------------------------------------------+
void ManageTFBoxes(int tf_idx, double p_h, double p_l, datetime p_t, bool p_conf, int tf_minutes,
                   bool &bear_ret, bool &bull_ret, string &bear_pat, string &bull_pat,
                   double &bear_lvl, double &bull_lvl, bool &bear_est, bool &bull_est,
                   bool &bear_est_valid, bool &bull_est_valid)
{
   bear_ret = false; bull_ret = false;
   bear_pat = ""; bull_pat = "";
   bear_lvl = 0; bull_lvl = 0;
   bear_est = false; bull_est = false;
   bear_est_valid = false; bull_est_valid = false;
   
   int protection_candles = IsEntry(tf_minutes) ? 3 : 1;
   int tf_seconds = tf_minutes * 60;
   
   for(int i = g_tf_box_count[tf_idx] - 1; i >= 0; i--)
   {
      if(!g_tf_boxes[tf_idx][i].active) continue;
      
      TrackedBox box; // local copy for readability
      box = g_tf_boxes[tf_idx][i];
      
      bool is_em = IsEMPattern(box.pattern_text);
      
      // Create visual box on first FORMING confirmation
      if(box.state == STATE_FORMING && box.obj_name == "" && p_conf)
      {
         string name = GenObjName("ZB");
         g_tf_boxes[tf_idx][i].obj_name = name;
         datetime t1 = iTime(_Symbol, PERIOD_CURRENT, 0);
         datetime t2 = GetFutureTime(50);
         
         color fill_c = box.box_clr;
         color brd_c = box.border_clr;
         ENUM_LINE_STYLE bstyle = STYLE_DASH;
         string txt = is_em ? box.pattern_text : "";
         
         CreateZoneBox(name, t1, box.top_val, t2, box.bottom_val,
                       fill_c, box.box_alpha, brd_c, 
                       is_em ? (uchar)UNRETESTED_BORDER_TRANS : box.border_alpha,
                       bstyle, 1, txt);
      }
      
      // Update visual appearance
      if(g_tf_boxes[tf_idx][i].obj_name != "")
      {
         string nm = g_tf_boxes[tf_idx][i].obj_name;
         if(ObjectFind(0, nm) >= 0)
         {
            if(g_tf_boxes[tf_idx][i].has_been_retested)
            {
               ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_SOLID);
               ObjectSetInteger(0, nm, OBJPROP_COLOR, box.border_clr);
            }
            else
            {
               ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_DASH);
            }
            // Extend right side
            ObjectSetInteger(0, nm, OBJPROP_TIME, 1, (long)GetFutureTime(50));
         }
      }
      
      // Bear direction logic
      if(box.direction == "bear")
      {
         // Invalidation: price broke above original top
         if(p_h > 0 && p_h > box.original_top)
         {
            // Delete visual
            if(g_tf_boxes[tf_idx][i].obj_name != "")
            {
               ObjectDelete(0, g_tf_boxes[tf_idx][i].obj_name);
               string txt_nm = g_tf_boxes[tf_idx][i].obj_name + "_txt";
               if(ObjectFind(0, txt_nm) >= 0) ObjectDelete(0, txt_nm);
            }
            // Remove
            for(int j = i; j < g_tf_box_count[tf_idx] - 1; j++)
               g_tf_boxes[tf_idx][j] = g_tf_boxes[tf_idx][j+1];
            g_tf_box_count[tf_idx]--;
            continue;
         }
         
         if(box.state == STATE_FORMING)
         {
            if(p_conf)
            {
               g_tf_boxes[tf_idx][i].state = STATE_ESTABLISHED;
               g_tf_boxes[tf_idx][i].just_established = true;
               g_tf_boxes[tf_idx][i].protection_end_time = p_t + (datetime)(tf_seconds * protection_candles);
               g_tf_boxes[tf_idx][i].protection_active = true;
               g_tf_boxes[tf_idx][i].est_wick_high = p_h;
               g_tf_boxes[tf_idx][i].est_wick_low = p_l;
            }
         }
         else if(box.state == STATE_ESTABLISHED)
         {
            bool wick_zone_touched = (p_h > 0 && p_h >= box.bottom_val && p_h < box.original_top);
            if(box.protection_active)
            {
               if(wick_zone_touched)
               {
                  bool wick_in_range = (box.est_wick_high > 0 && box.est_wick_low > 0 &&
                                       p_h >= box.est_wick_low && p_h <= box.est_wick_high);
                  if(wick_in_range)
                  {
                     g_tf_boxes[tf_idx][i].state = STATE_EST_RETEST;
                     g_tf_boxes[tf_idx][i].has_est_retest = true;
                     g_tf_boxes[tf_idx][i].has_been_retested = true;
                     g_tf_boxes[tf_idx][i].retest_type = "EST+RETEST";
                     bear_est = true;
                     bear_pat = box.pattern_text + " [EST+RET]";
                     bear_lvl = box.original_top;
                  }
                  else
                  {
                     g_tf_boxes[tf_idx][i].state = STATE_FORMING_FRESH;
                     g_tf_boxes[tf_idx][i].has_been_retested = true;
                     bear_ret = true;
                     bear_pat = box.pattern_text + " [FRESH FORMING]";
                     bear_lvl = box.original_top;
                  }
               }
               if(p_conf && p_t >= box.protection_end_time)
               {
                  g_tf_boxes[tf_idx][i].protection_active = false;
                  if(g_tf_boxes[tf_idx][i].state == STATE_ESTABLISHED)
                  {
                     g_tf_boxes[tf_idx][i].retest_type = "FRESH";
                     g_tf_boxes[tf_idx][i].completed_est_retest = true;
                  }
               }
            }
            else
            {
               if(wick_zone_touched)
               {
                  g_tf_boxes[tf_idx][i].state = STATE_RESPECTED;
                  g_tf_boxes[tf_idx][i].has_been_retested = true;
                  bear_ret = true;
                  bear_pat = box.pattern_text + " [FRESH]";
                  bear_lvl = box.original_top;
                  if(p_h > box.bottom_val && p_h < box.top_val)
                  {
                     g_tf_boxes[tf_idx][i].bottom_val = p_h;
                     if(g_tf_boxes[tf_idx][i].obj_name != "" && ObjectFind(0, g_tf_boxes[tf_idx][i].obj_name) >= 0)
                        ObjectSetDouble(0, g_tf_boxes[tf_idx][i].obj_name, OBJPROP_PRICE, 1, p_h);
                  }
               }
            }
         }
         else if(box.state == STATE_FORMING_FRESH)
         {
            bool wick_zone_touched = (p_h > 0 && p_h >= box.bottom_val && p_h < box.original_top);
            if(wick_zone_touched)
            {
               bear_ret = true;
               bear_pat = box.pattern_text + " [FRESH FORMING]";
               bear_lvl = box.original_top;
            }
            if(p_conf && p_t >= box.protection_end_time)
            {
               g_tf_boxes[tf_idx][i].state = STATE_RESPECTED;
               g_tf_boxes[tf_idx][i].protection_active = false;
               g_tf_boxes[tf_idx][i].retest_type = "FRESH";
               g_tf_boxes[tf_idx][i].completed_est_retest = true;
            }
         }
         else if(box.state == STATE_EST_RETEST)
         {
            bool wick_zone_touched = (p_h > 0 && p_h >= box.bottom_val && p_h < box.original_top);
            bear_est = true;
            bear_pat = box.pattern_text + " [EST+RET]";
            bear_lvl = box.original_top;
            if(wick_zone_touched) bear_ret = true;
            if(p_conf && p_t >= box.protection_end_time)
            {
               bear_est_valid = true;
               g_tf_boxes[tf_idx][i].state = STATE_RESPECTED;
               g_tf_boxes[tf_idx][i].protection_active = false;
               g_tf_boxes[tf_idx][i].retest_type = "FRESH";
               g_tf_boxes[tf_idx][i].completed_est_retest = true;
            }
         }
         else if(box.state == STATE_RESPECTED)
         {
            bool is_touching = (p_h > 0 && p_h >= box.bottom_val && p_l <= box.top_val);
            if(is_touching)
            {
               bear_ret = true;
               bear_pat = box.pattern_text + " [" + box.retest_type + "]";
               bear_lvl = box.original_top;
               if(p_h > box.bottom_val && p_h < box.top_val)
               {
                  g_tf_boxes[tf_idx][i].bottom_val = p_h;
                  if(g_tf_boxes[tf_idx][i].obj_name != "" && ObjectFind(0, g_tf_boxes[tf_idx][i].obj_name) >= 0)
                     ObjectSetDouble(0, g_tf_boxes[tf_idx][i].obj_name, OBJPROP_PRICE, 1, p_h);
               }
            }
         }
      }
      // Bull direction logic
      else if(box.direction == "bull")
      {
         if(p_l > 0 && p_l < box.original_bottom)
         {
            if(g_tf_boxes[tf_idx][i].obj_name != "")
            {
               ObjectDelete(0, g_tf_boxes[tf_idx][i].obj_name);
               string txt_nm2 = g_tf_boxes[tf_idx][i].obj_name + "_txt";
               if(ObjectFind(0, txt_nm2) >= 0) ObjectDelete(0, txt_nm2);
            }
            for(int j = i; j < g_tf_box_count[tf_idx] - 1; j++)
               g_tf_boxes[tf_idx][j] = g_tf_boxes[tf_idx][j+1];
            g_tf_box_count[tf_idx]--;
            continue;
         }
         
         if(box.state == STATE_FORMING)
         {
            if(p_conf)
            {
               g_tf_boxes[tf_idx][i].state = STATE_ESTABLISHED;
               g_tf_boxes[tf_idx][i].just_established = true;
               g_tf_boxes[tf_idx][i].protection_end_time = p_t + (datetime)(tf_seconds * protection_candles);
               g_tf_boxes[tf_idx][i].protection_active = true;
               g_tf_boxes[tf_idx][i].est_wick_high = p_h;
               g_tf_boxes[tf_idx][i].est_wick_low = p_l;
            }
         }
         else if(box.state == STATE_ESTABLISHED)
         {
            bool wick_zone_touched = (p_l > 0 && p_l <= box.top_val && p_l > box.original_bottom);
            if(box.protection_active)
            {
               if(wick_zone_touched)
               {
                  bool wick_in_range = (box.est_wick_high > 0 && box.est_wick_low > 0 &&
                                       p_l >= box.est_wick_low && p_l <= box.est_wick_high);
                  if(wick_in_range)
                  {
                     g_tf_boxes[tf_idx][i].state = STATE_EST_RETEST;
                     g_tf_boxes[tf_idx][i].has_est_retest = true;
                     g_tf_boxes[tf_idx][i].has_been_retested = true;
                     g_tf_boxes[tf_idx][i].retest_type = "EST+RETEST";
                     bull_est = true;
                     bull_pat = box.pattern_text + " [EST+RET]";
                     bull_lvl = box.original_bottom;
                  }
                  else
                  {
                     g_tf_boxes[tf_idx][i].state = STATE_FORMING_FRESH;
                     g_tf_boxes[tf_idx][i].has_been_retested = true;
                     bull_ret = true;
                     bull_pat = box.pattern_text + " [FRESH FORMING]";
                     bull_lvl = box.original_bottom;
                  }
               }
               if(p_conf && p_t >= box.protection_end_time)
               {
                  g_tf_boxes[tf_idx][i].protection_active = false;
                  if(g_tf_boxes[tf_idx][i].state == STATE_ESTABLISHED)
                  {
                     g_tf_boxes[tf_idx][i].retest_type = "FRESH";
                     g_tf_boxes[tf_idx][i].completed_est_retest = true;
                  }
               }
            }
            else
            {
               if(wick_zone_touched)
               {
                  g_tf_boxes[tf_idx][i].state = STATE_RESPECTED;
                  g_tf_boxes[tf_idx][i].has_been_retested = true;
                  bull_ret = true;
                  bull_pat = box.pattern_text + " [FRESH]";
                  bull_lvl = box.original_bottom;
                  if(p_l < box.top_val && p_l > box.bottom_val)
                  {
                     g_tf_boxes[tf_idx][i].top_val = p_l;
                     if(g_tf_boxes[tf_idx][i].obj_name != "" && ObjectFind(0, g_tf_boxes[tf_idx][i].obj_name) >= 0)
                        ObjectSetDouble(0, g_tf_boxes[tf_idx][i].obj_name, OBJPROP_PRICE, 0, p_l);
                  }
               }
            }
         }
         else if(box.state == STATE_FORMING_FRESH)
         {
            bool wick_zone_touched = (p_l > 0 && p_l <= box.top_val && p_l > box.original_bottom);
            if(wick_zone_touched)
            {
               bull_ret = true;
               bull_pat = box.pattern_text + " [FRESH FORMING]";
               bull_lvl = box.original_bottom;
            }
            if(p_conf && p_t >= box.protection_end_time)
            {
               g_tf_boxes[tf_idx][i].state = STATE_RESPECTED;
               g_tf_boxes[tf_idx][i].protection_active = false;
               g_tf_boxes[tf_idx][i].retest_type = "FRESH";
               g_tf_boxes[tf_idx][i].completed_est_retest = true;
            }
         }
         else if(box.state == STATE_EST_RETEST)
         {
            bool wick_zone_touched = (p_l > 0 && p_l <= box.top_val && p_l > box.original_bottom);
            bull_est = true;
            bull_pat = box.pattern_text + " [EST+RET]";
            bull_lvl = box.original_bottom;
            if(wick_zone_touched) bull_ret = true;
            if(p_conf && p_t >= box.protection_end_time)
            {
               bull_est_valid = true;
               g_tf_boxes[tf_idx][i].state = STATE_RESPECTED;
               g_tf_boxes[tf_idx][i].protection_active = false;
               g_tf_boxes[tf_idx][i].retest_type = "FRESH";
               g_tf_boxes[tf_idx][i].completed_est_retest = true;
            }
         }
         else if(box.state == STATE_RESPECTED)
         {
            bool is_touching = (p_l > 0 && p_l <= box.top_val && p_h >= box.bottom_val);
            if(is_touching)
            {
               bull_ret = true;
               bull_pat = box.pattern_text + " [" + box.retest_type + "]";
               bull_lvl = box.original_bottom;
               if(p_l < box.top_val && p_l > box.bottom_val)
               {
                  g_tf_boxes[tf_idx][i].top_val = p_l;
                  if(g_tf_boxes[tf_idx][i].obj_name != "" && ObjectFind(0, g_tf_boxes[tf_idx][i].obj_name) >= 0)
                     ObjectSetDouble(0, g_tf_boxes[tf_idx][i].obj_name, OBJPROP_PRICE, 0, p_l);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Create tracked box                                                |
//+------------------------------------------------------------------+
bool CreateTrackedBox(int tf_idx, string direction, double top_v, double bottom_v,
                      datetime creation_t, string pattern, int tf_minutes, bool is_intra)
{
   if(pattern == "" || top_v == 0 || bottom_v == 0 || creation_t == 0) return false;
   
   string tf_str = TFS[tf_idx];
   
   // Check if already exists
   for(int i = 0; i < g_tf_box_count[tf_idx]; i++)
   {
      if(!g_tf_boxes[tf_idx][i].active) continue;
      if(g_tf_boxes[tf_idx][i].creation_time == creation_t &&
         g_tf_boxes[tf_idx][i].direction == direction &&
         g_tf_boxes[tf_idx][i].timeframe == tf_str)
         return false;
   }
   
   if(g_tf_box_count[tf_idx] >= MAX_BOXES_PER_TF) return false;
   
   int idx = g_tf_box_count[tf_idx];
   bool is_em = IsEMPattern(pattern);
   string category = GetCategoryFromMinutes(tf_minutes);
   
   g_tf_boxes[tf_idx][idx].direction = direction;
   g_tf_boxes[tf_idx][idx].state = STATE_FORMING;
   g_tf_boxes[tf_idx][idx].top_val = top_v;
   g_tf_boxes[tf_idx][idx].bottom_val = bottom_v;
   g_tf_boxes[tf_idx][idx].original_top = top_v;
   g_tf_boxes[tf_idx][idx].original_bottom = bottom_v;
   g_tf_boxes[tf_idx][idx].creation_time = creation_t;
   g_tf_boxes[tf_idx][idx].pattern_text = pattern;
   g_tf_boxes[tf_idx][idx].base_pattern = pattern;
   g_tf_boxes[tf_idx][idx].timeframe = tf_str;
   g_tf_boxes[tf_idx][idx].is_intra = is_intra;
   g_tf_boxes[tf_idx][idx].is_em_forming = is_em;
   g_tf_boxes[tf_idx][idx].has_est_retest = false;
   g_tf_boxes[tf_idx][idx].retest_type = "FRESH";
   g_tf_boxes[tf_idx][idx].protection_active = true;
   g_tf_boxes[tf_idx][idx].hcs_count = 0;
   g_tf_boxes[tf_idx][idx].has_been_retested = false;
   g_tf_boxes[tf_idx][idx].completed_est_retest = false;
   g_tf_boxes[tf_idx][idx].just_established = false;
   g_tf_boxes[tf_idx][idx].est_wick_high = 0;
   g_tf_boxes[tf_idx][idx].est_wick_low = 0;
   g_tf_boxes[tf_idx][idx].obj_name = "";
   g_tf_boxes[tf_idx][idx].active = true;
   g_tf_boxes[tf_idx][idx].protection_end_time = 0;
   
   if(is_em)
   {
      if(category == "ENTRY")
      {
         g_tf_boxes[tf_idx][idx].box_clr = CLR_ENTRY_BOX;
         g_tf_boxes[tf_idx][idx].border_clr = CLR_ENTRY_BORDER;
         g_tf_boxes[tf_idx][idx].box_alpha = 242; // 95% transparency
         g_tf_boxes[tf_idx][idx].border_alpha = 128; // 50% transparency
      }
      else if(category == "SCALP")
      {
         g_tf_boxes[tf_idx][idx].box_clr = CLR_SCALP_BOX;
         g_tf_boxes[tf_idx][idx].border_clr = CLR_SCALP_BORDER;
         g_tf_boxes[tf_idx][idx].box_alpha = 230; // 90% transparency
         g_tf_boxes[tf_idx][idx].border_alpha = 128; // 50% transparency
      }
      else
      {
         g_tf_boxes[tf_idx][idx].box_clr = CLR_INTRA_BOX;
         g_tf_boxes[tf_idx][idx].border_clr = CLR_INTRA_BORDER;
         g_tf_boxes[tf_idx][idx].box_alpha = 242; // 95% transparency
         g_tf_boxes[tf_idx][idx].border_alpha = 128; // 50% transparency
      }
   }
   else
   {
      g_tf_boxes[tf_idx][idx].box_clr = clrWhite;
      g_tf_boxes[tf_idx][idx].border_clr = clrWhite;
      g_tf_boxes[tf_idx][idx].box_alpha = 255; // fully transparent
      g_tf_boxes[tf_idx][idx].border_alpha = 255;
   }
   
   g_tf_box_count[tf_idx]++;
   return true;
}

//+------------------------------------------------------------------+
//| Manage HCS boxes                                                  |
//+------------------------------------------------------------------+
bool ManageHCSBoxes(HcsBoxData &hcs_boxes[], int &count, bool is_bear)
{
   bool any_retesting = false;
   double h = iHigh(_Symbol, PERIOD_CURRENT, 0);
   double l = iLow(_Symbol, PERIOD_CURRENT, 0);
   int bar_idx = GetBarIndex();
   
   for(int i = count - 1; i >= 0; i--)
   {
      if(!hcs_boxes[i].active) continue;
      
      if(is_bear)
      {
         if(!hcs_boxes[i].is_broken && h > hcs_boxes[i].top_val)
         {
            hcs_boxes[i].is_broken = true;
            // Create HCS broken box visual
            string name = GenObjName("HCS");
            hcs_boxes[i].obj_name = name;
            datetime t1 = iTime(_Symbol, PERIOD_CURRENT, 
                          iBars(_Symbol, PERIOD_CURRENT) - 1 - hcs_boxes[i].creation_bar);
            datetime t2 = GetFutureTime(50);
            CreateZoneBox(name, t1, hcs_boxes[i].top_val, t2, hcs_boxes[i].bottom_val,
                         CLR_HCS_BEAR_BG, 204, CLR_HCS_BEAR_BORDER, 77,
                         STYLE_SOLID, 2,
                         "HCS BROKEN [" + hcs_boxes[i].tf_label + "]");
         }
         if(hcs_boxes[i].is_broken && hcs_boxes[i].obj_name != "")
         {
            if(h >= hcs_boxes[i].bottom_val && h <= hcs_boxes[i].top_val)
               any_retesting = true;
            if(l < hcs_boxes[i].bottom_val)
            {
               ObjectDelete(0, hcs_boxes[i].obj_name);
               string txt_nm3 = hcs_boxes[i].obj_name + "_txt";
               if(ObjectFind(0, txt_nm3) >= 0) ObjectDelete(0, txt_nm3);
               for(int j = i; j < count - 1; j++)
                  hcs_boxes[j] = hcs_boxes[j+1];
               count--;
               continue;
            }
            if(l <= hcs_boxes[i].top_val && l >= hcs_boxes[i].bottom_val)
            {
               if(l < hcs_boxes[i].top_val)
               {
                  hcs_boxes[i].top_val = l;
                  if(ObjectFind(0, hcs_boxes[i].obj_name) >= 0)
                     ObjectSetDouble(0, hcs_boxes[i].obj_name, OBJPROP_PRICE, 0, l);
               }
            }
         }
      }
      else
      {
         if(!hcs_boxes[i].is_broken && l < hcs_boxes[i].bottom_val)
         {
            hcs_boxes[i].is_broken = true;
            string name = GenObjName("HCS");
            hcs_boxes[i].obj_name = name;
            datetime t1 = iTime(_Symbol, PERIOD_CURRENT,
                          iBars(_Symbol, PERIOD_CURRENT) - 1 - hcs_boxes[i].creation_bar);
            datetime t2 = GetFutureTime(50);
            CreateZoneBox(name, t1, hcs_boxes[i].top_val, t2, hcs_boxes[i].bottom_val,
                         CLR_HCS_BULL_BG, 204, CLR_HCS_BULL_BORDER, 77,
                         STYLE_SOLID, 2,
                         "HCS BROKEN [" + hcs_boxes[i].tf_label + "]");
         }
         if(hcs_boxes[i].is_broken && hcs_boxes[i].obj_name != "")
         {
            if(l >= hcs_boxes[i].bottom_val && l <= hcs_boxes[i].top_val)
               any_retesting = true;
            if(h > hcs_boxes[i].top_val)
            {
               ObjectDelete(0, hcs_boxes[i].obj_name);
               string txt_nm4 = hcs_boxes[i].obj_name + "_txt";
               if(ObjectFind(0, txt_nm4) >= 0) ObjectDelete(0, txt_nm4);
               for(int j = i; j < count - 1; j++)
                  hcs_boxes[j] = hcs_boxes[j+1];
               count--;
               continue;
            }
            if(l >= hcs_boxes[i].bottom_val && l <= hcs_boxes[i].top_val)
            {
               if(l > hcs_boxes[i].bottom_val)
               {
                  hcs_boxes[i].bottom_val = l;
                  if(ObjectFind(0, hcs_boxes[i].obj_name) >= 0)
                     ObjectSetDouble(0, hcs_boxes[i].obj_name, OBJPROP_PRICE, 1, l);
               }
            }
         }
      }
   }
   return any_retesting;
}

//+------------------------------------------------------------------+
//| Check LV break                                                    |
//+------------------------------------------------------------------+
void CheckLVBreak(LastValidInfo &lv, double h, double l)
{
   if(lv.original_text != "None" && lv.level > 0)
   {
      if(lv.direction == "bear" && h > lv.level)
      {
         lv.pattern_text = "BROKEN (was " + lv.original_text + ")";
         lv.is_broken = true;
      }
      if(lv.direction == "bull" && l < lv.level)
      {
         lv.pattern_text = "BROKEN (was " + lv.original_text + ")";
         lv.is_broken = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Resolve last valid                                                |
//+------------------------------------------------------------------+
void ResolveLV(LastValidInfo &bear_lv, LastValidInfo &bull_lv,
               string &lv_text, string &lv_dir, string &lv_orig_dir, bool &lv_broken)
{
   lv_text = "None";
   lv_dir = "";
   lv_orig_dir = "";
   lv_broken = false;
   
   if(bear_lv.est_time > 0 || bull_lv.est_time > 0)
   {
      if(bear_lv.est_time > bull_lv.est_time)
      {
         lv_text = bear_lv.pattern_text + TimeAgo(bear_lv.est_time);
         lv_dir = bear_lv.is_broken ? "bull" : "bear";
         lv_orig_dir = "bear";
         lv_broken = bear_lv.is_broken;
      }
      else
      {
         lv_text = bull_lv.pattern_text + TimeAgo(bull_lv.est_time);
         lv_dir = bull_lv.is_broken ? "bear" : "bull";
         lv_orig_dir = "bull";
         lv_broken = bull_lv.is_broken;
      }
   }
}

//+------------------------------------------------------------------+
//| Find next extreme candle for SL extension                         |
//+------------------------------------------------------------------+
double FindNextExtremeCandle(string direction, double original_sl, int lookback=500)
{
   if(direction == "bear")
   {
      for(int i = 1; i <= lookback; i++)
      {
         double h = iHigh(_Symbol, PERIOD_CURRENT, i);
         if(h > original_sl) return h;
      }
   }
   else
   {
      for(int i = 1; i <= lookback; i++)
      {
         double l = iLow(_Symbol, PERIOD_CURRENT, i);
         if(l < original_sl) return l;
      }
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Create RR box set (visual)                                        |
//+------------------------------------------------------------------+
void CreateRRBoxVisual(string &sl_name, string &tp_name, string &pip_name,
                       double sl_level, double entry_level, double tp_level, double pip_level,
                       string text, bool is_forming)
{
   datetime t1 = iTime(_Symbol, PERIOD_CURRENT, 0);
   datetime t2 = GetFutureTime(3);
   
   sl_name = GenObjName("RR_SL");
   tp_name = GenObjName("RR_TP");
   pip_name = GenObjName("RR_PIP");
   
   ENUM_LINE_STYLE bstyle = is_forming ? STYLE_DASH : STYLE_SOLID;
   
   // SL box
   CreateZoneBox(sl_name, t1, sl_level, t2, entry_level,
                CLR_RR_SL, is_forming ? (uchar)230 : (uchar)217, CLR_RR_SL, 153,
                bstyle, 1, is_forming ? "FORMING" : "");
   
   // TP box
   CreateZoneBox(tp_name, t1, entry_level, t2, tp_level,
                CLR_RR_TP, is_forming ? (uchar)230 : (uchar)217, CLR_RR_TP, 153,
                bstyle, 1, text);
   
   // Pip target line
   CreateLine(pip_name, t1, pip_level, t2, pip_level,
             CLR_RR_TP, 1, is_forming ? STYLE_DOT : STYLE_SOLID);
}

//+------------------------------------------------------------------+
//| Delete forming RR objects                                         |
//+------------------------------------------------------------------+
void DeleteFormingRR(string &sl_name, string &tp_name, string &pip_name, int &bar)
{
   if(sl_name != "")
   {
      ObjectDelete(0, sl_name);
      string txt_nm5 = sl_name + "_txt";
      if(ObjectFind(0, txt_nm5) >= 0) ObjectDelete(0, txt_nm5);
   }
   if(tp_name != "")
   {
      ObjectDelete(0, tp_name);
      string txt_nm6 = tp_name + "_txt";
      if(ObjectFind(0, txt_nm6) >= 0) ObjectDelete(0, txt_nm6);
   }
   if(pip_name != "")
      ObjectDelete(0, pip_name);
   sl_name = "";
   tp_name = "";
   pip_name = "";
   bar = -1;
}

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   pip_value = _Point * 10;
   g_obj_counter = 0;
   
   // Initialize TF strings and labels
   for(int i = 0; i < TF_COUNT; i++)
   {
      TFS[i] = IntegerToString(TF_MINUTES[i]);
      TF_LABELS[i] = FormatTFLabel(TF_MINUTES[i]);
      TF_CATEGORIES[i] = GetCategoryFromMinutes(TF_MINUTES[i]);
      
      g_tf_box_count[i] = 0;
      arr_bear_seq[i].Reset();
      arr_bull_seq[i].Reset();
      arr_bear_third_step[i] = 0;
      arr_bull_third_step[i] = 0;
      arr_bear_laol_step[i] = 0;
      arr_bull_laol_step[i] = 0;
      arr_last_bear_hcs_time[i] = 0;
      arr_last_bull_hcs_time[i] = 0;
      arr_bear_hcs_broken[i] = false;
      arr_bull_hcs_broken[i] = false;
      arr_bear_hcs_retesting[i] = false;
      arr_bull_hcs_retesting[i] = false;
   }
   
   // Initialize LAOL counts
   g_bear_laol_count = 0;
   g_bull_laol_count = 0;
   g_bear_scalp_laol_count = 0;
   g_bull_scalp_laol_count = 0;
   g_bear_intra_laol_count = 0;
   g_bull_intra_laol_count = 0;
   
   // Initialize HCS
   g_hcs_bear_count = 0;
   g_hcs_bull_count = 0;
   
   // Initialize RR
   g_rr_bear_count = 0;
   g_rr_bull_count = 0;
   
   // Initialize XLAOL
   g_xlaol_count = 0;
   
   // Initialize LV
   entry_bear_lv.Reset();
   entry_bull_lv.Reset();
   scalp_bear_lv.Reset();
   scalp_bull_lv.Reset();
   intra_bear_lv.Reset();
   intra_bull_lv.Reset();
   
   // Initialize state
   last_bear_laol_break_time = 0;
   last_bull_laol_break_time = 0;
   last_bear_scalp_laol_break_time = 0;
   last_bull_scalp_laol_break_time = 0;
   last_bear_intra_laol_break_time = 0;
   last_bull_intra_laol_break_time = 0;
   final_entry_bear_setup_bar = -1;
   final_entry_bull_setup_bar = -1;
   final_entry_bear_pattern = "";
   final_entry_bull_pattern = "";
   last_bear_forming_bar = -1;
   last_bear_confirmed_bar = -1;
   last_bull_forming_bar = -1;
   last_bull_confirmed_bar = -1;
   intra_bear_negating = false;
   intra_bull_negating = false;
   
   bear_forming_rr_sl_name = "";
   bear_forming_rr_tp_name = "";
   bear_forming_rr_pip_name = "";
   bear_forming_rr_bar = -1;
   bear_forming_type = "";
   bear_forming_type_prev = "";
   bull_forming_rr_sl_name = "";
   bull_forming_rr_tp_name = "";
   bull_forming_rr_pip_name = "";
   bull_forming_rr_bar = -1;
   bull_forming_type = "";
   bull_forming_type_prev = "";
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit - cleanup all objects                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "STX_");
}

//+------------------------------------------------------------------+
//| OnCalculate - main processing loop                                |
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
   if(rates_total < 10) return rates_total;
   
   // Only process new bars + current tick
   int limit = rates_total - prev_calculated;
   if(limit > 1) limit = 1; // Process last bar only on startup
   
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   //--- Get MTF data for all 25 timeframes
   double o2,h2,l2,c2, o1,h1,l1,c1, o0,h0,l0,c0;
   datetime t0;
   bool is_conf;
   
   for(int i = 0; i < TF_COUNT; i++)
   {
      // Skip INTRA timeframes if soft start not enabled
      if(!InpSoftStart && i >= INTRA_MIN_IDX)
         continue;
         
      ENUM_TIMEFRAMES tf = GetTimeframe(TF_MINUTES[i]);
      if(GetTFData(tf, o2,h2,l2,c2, o1,h1,l1,c1, o0,h0,l0,c0, t0, is_conf))
         CalculatePatterns(i, o2,h2,l2,c2, o1,h1,l1,c1, o0,h0,l0,c0, t0, is_conf);
   }
   
   //--- SN counting
   int entry_sn_bear_count=0, entry_sn_bull_count=0;
   int scalp_sn_bear_count=0, scalp_sn_bull_count=0;
   int intra_sn_bear_count=0, intra_sn_bull_count=0;
   
   for(int i = 0; i < TF_COUNT; i++)
   {
      string cat = TF_CATEGORIES[i];
      if(arr_sn_bear[i])
      {
         if(cat == "ENTRY") entry_sn_bear_count++;
         else if(cat == "SCALP") scalp_sn_bear_count++;
         else if(cat == "INTRA") intra_sn_bear_count++;
      }
      if(arr_sn_bull[i])
      {
         if(cat == "ENTRY") entry_sn_bull_count++;
         else if(cat == "SCALP") scalp_sn_bull_count++;
         else if(cat == "INTRA") intra_sn_bull_count++;
      }
   }

   //--- Third pattern detection (2-step confirmation)
   for(int i = 0; i < TF_COUNT; i++)
   {
      string cat = TF_CATEGORIES[i];
      if(cat == "NONE") continue;
      bool i_conf = arr_tf_conf[i];
      double i_h = arr_tf_h[i];
      double i_l = arr_tf_l[i];
      datetime i_t = arr_tf_t[i];
      
      // Bear third step
      if(arr_bear_third_step[i] == 1 && i_conf)
      {
         datetime ref_time = arr_bear_third_ref_time[i];
         if(ref_time > 0 && i_t > ref_time)
         {
            double ref_h = arr_bear_third_ref_h[i];
            double ref_l = arr_bear_third_ref_l[i];
            if(ref_h > 0 && ref_l > 0 && i_h > ref_h && i_l > ref_l)
               arr_third_bear[i] = true;
            arr_bear_third_step[i] = 0;
            arr_bear_third_ref_h[i] = 0;
            arr_bear_third_ref_l[i] = 0;
            arr_bear_third_ref_time[i] = 0;
         }
      }
      if(arr_second_bear[i] && i_conf)
      {
         arr_bear_third_step[i] = 1;
         arr_bear_third_ref_h[i] = i_h;
         arr_bear_third_ref_l[i] = i_l;
         arr_bear_third_ref_time[i] = i_t;
      }
      
      // Bull third step
      if(arr_bull_third_step[i] == 1 && i_conf)
      {
         datetime ref_time2 = arr_bull_third_ref_time[i];
         if(ref_time2 > 0 && i_t > ref_time2)
         {
            double ref_h2b = arr_bull_third_ref_h[i];
            double ref_l2b = arr_bull_third_ref_l[i];
            if(ref_h2b > 0 && ref_l2b > 0 && i_l < ref_l2b && i_h < ref_h2b)
               arr_third_bull[i] = true;
            arr_bull_third_step[i] = 0;
            arr_bull_third_ref_h[i] = 0;
            arr_bull_third_ref_l[i] = 0;
            arr_bull_third_ref_time[i] = 0;
         }
      }
      if(arr_second_bull[i] && i_conf)
      {
         arr_bull_third_step[i] = 1;
         arr_bull_third_ref_h[i] = i_h;
         arr_bull_third_ref_l[i] = i_l;
         arr_bull_third_ref_time[i] = i_t;
      }
      
      // Bear LAOL step
      if(arr_bear_laol_step[i] == 1 && i_conf)
      {
         datetime ref_time3 = arr_bear_laol_ref_time[i];
         if(ref_time3 > 0 && i_t > ref_time3)
         {
            double ref_h3 = arr_bear_laol_ref_h[i];
            double ref_l3 = arr_bear_laol_ref_l[i];
            if(ref_h3 > 0 && ref_l3 > 0 && i_h > ref_h3 && i_l > ref_l3)
               arr_laol_bear[i] = true;
            arr_bear_laol_step[i] = 0;
            arr_bear_laol_ref_h[i] = 0;
            arr_bear_laol_ref_l[i] = 0;
            arr_bear_laol_ref_time[i] = 0;
         }
      }
      if(arr_laol_first_bear[i] && i_conf)
      {
         arr_bear_laol_step[i] = 1;
         arr_bear_laol_ref_h[i] = i_h;
         arr_bear_laol_ref_l[i] = i_l;
         arr_bear_laol_ref_time[i] = i_t;
      }
      
      // Bull LAOL step
      if(arr_bull_laol_step[i] == 1 && i_conf)
      {
         datetime ref_time4 = arr_bull_laol_ref_time[i];
         if(ref_time4 > 0 && i_t > ref_time4)
         {
            double ref_h4 = arr_bull_laol_ref_h[i];
            double ref_l4 = arr_bull_laol_ref_l[i];
            if(ref_h4 > 0 && ref_l4 > 0 && i_h < ref_h4 && i_l < ref_l4)
               arr_laol_bull[i] = true;
            arr_bull_laol_step[i] = 0;
            arr_bull_laol_ref_h[i] = 0;
            arr_bull_laol_ref_l[i] = 0;
            arr_bull_laol_ref_time[i] = 0;
         }
      }
      if(arr_laol_first_bull[i] && i_conf)
      {
         arr_bull_laol_step[i] = 1;
         arr_bull_laol_ref_h[i] = i_h;
         arr_bull_laol_ref_l[i] = i_l;
         arr_bull_laol_ref_time[i] = i_t;
      }
   }

   //--- Main TF processing loop: HCS, pattern building, box creation & management
   for(int i = 0; i < TF_COUNT; i++)
   {
      string tf_str = TFS[i];
      string tf_category = TF_CATEGORIES[i];
      if(tf_category == "NONE") continue;
      
      bool should_show = (tf_category == "ENTRY" || tf_category == "SCALP" || 
                          (tf_category == "INTRA" && InpSoftStart));
      
      double i_h = arr_tf_h[i];
      double i_l = arr_tf_l[i];
      datetime i_t = arr_tf_t[i];
      bool i_conf = arr_tf_conf[i];
      double i_bt = arr_tf_bt[i];
      double i_bb = arr_tf_bb[i];
      bool i_fu_bear = arr_fu_bear[i];
      bool i_fu_bull = arr_fu_bull[i];
      bool i_sn_bear = arr_sn_bear[i];
      bool i_sn_bull = arr_sn_bull[i];
      bool i_third_bear = arr_third_bear[i];
      bool i_third_bull = arr_third_bull[i];
      bool i_first_bear = arr_first_bear[i];
      bool i_first_bull = arr_first_bull[i];
      bool i_laol_bear = arr_laol_bear[i];
      bool i_laol_bull = arr_laol_bull[i];
      
      // TBE sequence update
      bool i_x3_bear = i_third_bear || i_first_bear;
      bool i_x3_bull = i_third_bull || i_first_bull;
      bool bear_tbe = UpdateSeq(arr_bear_seq[i], i_fu_bear, i_x3_bear, i_fu_bull, i_x3_bull,
                                i_h, i_bt, TF_MINUTES[i], i_conf, true, i_h, i_l);
      bool bull_tbe = UpdateSeq(arr_bull_seq[i], i_fu_bull, i_x3_bull, i_fu_bear, i_x3_bear,
                                i_l, i_bb, TF_MINUTES[i], i_conf, false, i_h, i_l);
      
      bool sn_dbl_bear = i_sn_bear && (tf_category == "ENTRY" ? entry_sn_bear_count >= 2 :
                          tf_category == "SCALP" ? scalp_sn_bear_count >= 2 : intra_sn_bear_count >= 2);
      bool sn_dbl_bull = i_sn_bull && (tf_category == "ENTRY" ? entry_sn_bull_count >= 2 :
                          tf_category == "SCALP" ? scalp_sn_bull_count >= 2 : intra_sn_bull_count >= 2);
      
      bool bear_hcs = false, bull_hcs = false;
      bool bear_hcs_forming = false, bull_hcs_forming = false;
      
      if(should_show)
      {
         // HCS detection: check if new FU/SN is inside existing box
         bool new_bear_fu_sn = i_fu_bear || i_sn_bear;
         bool new_bull_fu_sn = i_fu_bull || i_sn_bull;
         
         if(g_tf_box_count[i] > 0 && (new_bear_fu_sn || new_bull_fu_sn))
         {
            for(int b = 0; b < g_tf_box_count[i]; b++)
            {
               if(!g_tf_boxes[i][b].active) continue;
               if(g_tf_boxes[i][b].timeframe != tf_str) continue;
               if(g_tf_boxes[i][b].creation_time == i_t) continue;
               if(g_tf_boxes[i][b].state == STATE_FORMING) continue;
               
               bool bx_has_fu_sn = StrContains(g_tf_boxes[i][b].base_pattern, "FU") ||
                                   StrContains(g_tf_boxes[i][b].base_pattern, "SN");
               if(!bx_has_fu_sn) continue;
               
               if(g_tf_boxes[i][b].direction == "bear" && new_bear_fu_sn)
               {
                  if(i_h > 0 && i_h >= g_tf_boxes[i][b].bottom_val && i_h <= g_tf_boxes[i][b].original_top)
                  {
                     if(i_conf)
                     {
                        if(arr_last_bear_hcs_time[i] != i_t)
                        {
                           bear_hcs = true;
                           g_tf_boxes[i][b].hcs_count++;
                           g_tf_boxes[i][b].pattern_text = g_tf_boxes[i][b].base_pattern +
                              " [HCS X" + IntegerToString(g_tf_boxes[i][b].hcs_count) + "]";
                           arr_last_bear_hcs_time[i] = i_t;
                           
                           if(InpShowHCSBoxes && g_tf_boxes[i][b].hcs_count == 1 &&
                              (tf_str == "50" || tf_str == "60"))
                           {
                              if(g_hcs_bear_count < MAX_HCS_BOXES)
                              {
                                 int hi = g_hcs_bear_count;
                                 g_hcs_boxes_bear[hi].top_val = g_tf_boxes[i][b].original_top;
                                 g_hcs_boxes_bear[hi].bottom_val = g_tf_boxes[i][b].original_bottom;
                                 g_hcs_boxes_bear[hi].creation_bar = GetBarIndex();
                                 g_hcs_boxes_bear[hi].tf_label = TF_LABELS[i];
                                 g_hcs_boxes_bear[hi].direction = "bear";
                                 g_hcs_boxes_bear[hi].is_broken = false;
                                 g_hcs_boxes_bear[hi].active = true;
                                 g_hcs_boxes_bear[hi].obj_name = "";
                                 g_hcs_bear_count++;
                              }
                           }
                        }
                     }
                     else
                        bear_hcs_forming = true;
                  }
               }
               if(g_tf_boxes[i][b].direction == "bull" && new_bull_fu_sn)
               {
                  if(i_l > 0 && i_l <= g_tf_boxes[i][b].top_val && i_l >= g_tf_boxes[i][b].original_bottom)
                  {
                     if(i_conf)
                     {
                        if(arr_last_bull_hcs_time[i] != i_t)
                        {
                           bull_hcs = true;
                           g_tf_boxes[i][b].hcs_count++;
                           g_tf_boxes[i][b].pattern_text = g_tf_boxes[i][b].base_pattern +
                              " [HCS X" + IntegerToString(g_tf_boxes[i][b].hcs_count) + "]";
                           arr_last_bull_hcs_time[i] = i_t;
                           
                           if(InpShowHCSBoxes && g_tf_boxes[i][b].hcs_count == 1 &&
                              (tf_str == "50" || tf_str == "60"))
                           {
                              if(g_hcs_bull_count < MAX_HCS_BOXES)
                              {
                                 int hi2 = g_hcs_bull_count;
                                 g_hcs_boxes_bull[hi2].top_val = g_tf_boxes[i][b].original_top;
                                 g_hcs_boxes_bull[hi2].bottom_val = g_tf_boxes[i][b].original_bottom;
                                 g_hcs_boxes_bull[hi2].creation_bar = GetBarIndex();
                                 g_hcs_boxes_bull[hi2].tf_label = TF_LABELS[i];
                                 g_hcs_boxes_bull[hi2].direction = "bull";
                                 g_hcs_boxes_bull[hi2].is_broken = false;
                                 g_hcs_boxes_bull[hi2].active = true;
                                 g_hcs_boxes_bull[hi2].obj_name = "";
                                 g_hcs_bull_count++;
                              }
                           }
                        }
                     }
                     else
                        bull_hcs_forming = true;
                  }
               }
            }
         }
         
         arr_bear_hcs[i] = bear_hcs;
         arr_bull_hcs[i] = bull_hcs;
         arr_bear_hcs_forming[i] = bear_hcs_forming;
         arr_bull_hcs_forming[i] = bull_hcs_forming;
         
         // Build pattern strings
         string bear_pattern = BuildPatternStr(true, i_third_bear, i_first_bear, i_laol_bear,
                                              i_sn_bear, sn_dbl_bear, i_fu_bear, bear_tbe, bear_hcs, bear_hcs_forming);
         string bull_pattern = BuildPatternStr(false, i_third_bull, i_first_bull, i_laol_bull,
                                              i_sn_bull, sn_dbl_bull, i_fu_bull, bull_tbe, bull_hcs, bull_hcs_forming);
         
         // Create new boxes
         if(bear_pattern != "" && i_h > 0 && i_bt > 0 && i_t > 0)
            CreateTrackedBox(i, "bear", i_h, i_bt, i_t, bear_pattern, TF_MINUTES[i], tf_category == "INTRA");
         if(bull_pattern != "" && i_l > 0 && i_bb > 0 && i_t > 0)
            CreateTrackedBox(i, "bull", i_bb, i_l, i_t, bull_pattern, TF_MINUTES[i], tf_category == "INTRA");
         
         // Manage existing boxes
         bool bear_ret, bull_ret, bear_est2, bull_est2, bear_est_valid2, bull_est_valid2;
         string bear_pat, bull_pat;
         double bear_lvl, bull_lvl;
         ManageTFBoxes(i, i_h, i_l, i_t, i_conf, TF_MINUTES[i],
                      bear_ret, bull_ret, bear_pat, bull_pat, bear_lvl, bull_lvl,
                      bear_est2, bull_est2, bear_est_valid2, bull_est_valid2);
         
         arr_bear_retesting[i] = bear_ret;
         arr_bull_retesting[i] = bull_ret;
         arr_bear_retest_pattern[i] = bear_pat;
         arr_bull_retest_pattern[i] = bull_pat;
         arr_bear_retest_level[i] = bear_lvl;
         arr_bull_retest_level[i] = bull_lvl;
         arr_bear_est_retest[i] = bear_est2;
         arr_bull_est_retest[i] = bull_est2;
         arr_bear_est_retest_VALID[i] = bear_est_valid2;
         arr_bull_est_retest_VALID[i] = bull_est_valid2;
         
         // Scan LAOL in newly established SCALP boxes
         if(tf_category == "SCALP")
         {
            for(int b2 = 0; b2 < g_tf_box_count[i]; b2++)
            {
               if(!g_tf_boxes[i][b2].active) continue;
               if(!g_tf_boxes[i][b2].just_established) continue;
               if(!IsEMPattern(g_tf_boxes[i][b2].pattern_text))
               {
                  g_tf_boxes[i][b2].just_established = false;
                  continue;
               }
               g_tf_boxes[i][b2].just_established = false;
               ScanLaolInBox(g_bear_laol, g_bear_laol_count,
                            g_tf_boxes[i][b2].original_top, g_tf_boxes[i][b2].original_bottom,
                            true, "ENTRY", "SCALP");
               ScanLaolInBox(g_bull_laol, g_bull_laol_count,
                            g_tf_boxes[i][b2].original_top, g_tf_boxes[i][b2].original_bottom,
                            false, "ENTRY", "SCALP");
            }
         }
         // Scan LAOL in newly established INTRA boxes
         if(tf_category == "INTRA" && InpSoftStart)
         {
            for(int b3 = 0; b3 < g_tf_box_count[i]; b3++)
            {
               if(!g_tf_boxes[i][b3].active) continue;
               if(!g_tf_boxes[i][b3].just_established) continue;
               if(!IsEMPattern(g_tf_boxes[i][b3].pattern_text))
               {
                  g_tf_boxes[i][b3].just_established = false;
                  continue;
               }
               g_tf_boxes[i][b3].just_established = false;
               ScanLaolInBox(g_bear_scalp_laol, g_bear_scalp_laol_count,
                            g_tf_boxes[i][b3].original_top, g_tf_boxes[i][b3].original_bottom,
                            true, "SCALP", "INTRA");
               ScanLaolInBox(g_bull_scalp_laol, g_bull_scalp_laol_count,
                            g_tf_boxes[i][b3].original_top, g_tf_boxes[i][b3].original_bottom,
                            false, "SCALP", "INTRA");
               ScanLaolInBox(g_bear_laol, g_bear_laol_count,
                            g_tf_boxes[i][b3].original_top, g_tf_boxes[i][b3].original_bottom,
                            true, "ENTRY", "INTRA");
               ScanLaolInBox(g_bull_laol, g_bull_laol_count,
                            g_tf_boxes[i][b3].original_top, g_tf_boxes[i][b3].original_bottom,
                            false, "ENTRY", "INTRA");
            }
         }
      }
      
      // LAOL line creation from inside bars
      if(tf_category == "ENTRY" && should_show && i_conf)
      {
         if(arr_laol_candle_bear[i])
         {
            if(!MergeCrossCategory(g_bear_laol, g_bear_laol_count,
                                   g_bear_scalp_laol, g_bear_scalp_laol_count,
                                   g_bear_intra_laol, g_bear_intra_laol_count,
                                   i_h, TF_LABELS[i], true))
               AddOrMergeLaolLine(g_bear_laol, g_bear_laol_count, i_h, TF_LABELS[i], true, "ENTRY");
         }
         if(arr_laol_candle_bull[i])
         {
            if(!MergeCrossCategory(g_bull_laol, g_bull_laol_count,
                                   g_bull_scalp_laol, g_bull_scalp_laol_count,
                                   g_bull_intra_laol, g_bull_intra_laol_count,
                                   i_l, TF_LABELS[i], false))
               AddOrMergeLaolLine(g_bull_laol, g_bull_laol_count, i_l, TF_LABELS[i], false, "ENTRY");
         }
      }
      if(tf_category == "SCALP" && should_show && i_conf)
      {
         if(arr_laol_candle_bear[i])
         {
            if(!MergeCrossCategory(g_bear_laol, g_bear_laol_count,
                                   g_bear_scalp_laol, g_bear_scalp_laol_count,
                                   g_bear_intra_laol, g_bear_intra_laol_count,
                                   i_h, TF_LABELS[i], true))
               AddOrMergeLaolLine(g_bear_scalp_laol, g_bear_scalp_laol_count, i_h, TF_LABELS[i], true, "SCALP");
         }
         if(arr_laol_candle_bull[i])
         {
            if(!MergeCrossCategory(g_bull_laol, g_bull_laol_count,
                                   g_bull_scalp_laol, g_bull_scalp_laol_count,
                                   g_bull_intra_laol, g_bull_intra_laol_count,
                                   i_l, TF_LABELS[i], false))
               AddOrMergeLaolLine(g_bull_scalp_laol, g_bull_scalp_laol_count, i_l, TF_LABELS[i], false, "SCALP");
         }
      }
      if(tf_category == "INTRA" && i_conf)
      {
         if(arr_laol_candle_bear[i])
         {
            if(!MergeCrossCategory(g_bear_laol, g_bear_laol_count,
                                   g_bear_scalp_laol, g_bear_scalp_laol_count,
                                   g_bear_intra_laol, g_bear_intra_laol_count,
                                   i_h, TF_LABELS[i], true))
               AddOrMergeLaolLine(g_bear_intra_laol, g_bear_intra_laol_count, i_h, TF_LABELS[i], true, "INTRA");
         }
         if(arr_laol_candle_bull[i])
         {
            if(!MergeCrossCategory(g_bull_laol, g_bull_laol_count,
                                   g_bull_scalp_laol, g_bull_scalp_laol_count,
                                   g_bull_intra_laol, g_bull_intra_laol_count,
                                   i_l, TF_LABELS[i], false))
               AddOrMergeLaolLine(g_bull_intra_laol, g_bull_intra_laol_count, i_l, TF_LABELS[i], false, "INTRA");
         }
      }
   }

   //--- Update LAOL lines (break detection)
   double cur_high = iHigh(_Symbol, PERIOD_CURRENT, 0);
   double cur_low = iLow(_Symbol, PERIOD_CURRENT, 0);
   
   datetime bt1, bt2, bt3, sbt1, sbt2, sbt3;
   string btf1, btf2, btf3, sbtf1, sbtf2, sbtf3;
   datetime ibt1, ibt2, ibt3;
   string ibtf1, ibtf2, ibtf3;
   
   UpdateLaolLines(g_bear_laol, g_bear_laol_count, true, cur_high, bt1, btf1, ibt1, ibtf1, sbt1, sbtf1);
   UpdateLaolLines(g_bull_laol, g_bull_laol_count, false, cur_low, bt2, btf2, ibt2, ibtf2, sbt2, sbtf2);
   
   if(bt1 > 0) { last_bear_laol_break_time = bt1; last_bear_laol_tf = btf1; }
   if(bt2 > 0) { last_bull_laol_break_time = bt2; last_bull_laol_tf = btf2; }
   if(ibt1 > 0) { last_bear_intra_laol_break_time = ibt1; last_bear_intra_laol_tf = ibtf1; }
   if(ibt2 > 0) { last_bull_intra_laol_break_time = ibt2; last_bull_intra_laol_tf = ibtf2; }
   if(sbt1 > 0) { last_bear_scalp_laol_break_time = sbt1; last_bear_scalp_laol_tf = sbtf1; }
   if(sbt2 > 0) { last_bull_scalp_laol_break_time = sbt2; last_bull_scalp_laol_tf = sbtf2; }
   
   // Update scalp LAOL lines
   datetime bt4, bt5, sbt4, sbt5, ibt4, ibt5;
   string btf4, btf5, sbtf4, sbtf5, ibtf4, ibtf5;
   UpdateLaolLines(g_bear_scalp_laol, g_bear_scalp_laol_count, true, cur_high, bt4, btf4, ibt4, ibtf4, sbt4, sbtf4);
   UpdateLaolLines(g_bull_scalp_laol, g_bull_scalp_laol_count, false, cur_low, bt5, btf5, ibt5, ibtf5, sbt5, sbtf5);
   if(ibt4 > 0) { last_bear_intra_laol_break_time = ibt4; last_bear_intra_laol_tf = ibtf4; }
   if(ibt5 > 0) { last_bull_intra_laol_break_time = ibt5; last_bull_intra_laol_tf = ibtf5; }
   if(sbt4 > 0) { last_bear_scalp_laol_break_time = sbt4; last_bear_scalp_laol_tf = sbtf4; }
   if(sbt5 > 0) { last_bull_scalp_laol_break_time = sbt5; last_bull_scalp_laol_tf = sbtf5; }
   
   // Update intra LAOL lines
   datetime bt6, bt7, sbt6, sbt7, ibt6, ibt7;
   string btf6, btf7, sbtf6, sbtf7, ibtf6, ibtf7;
   UpdateLaolLines(g_bear_intra_laol, g_bear_intra_laol_count, true, cur_high, bt6, btf6, ibt6, ibtf6, sbt6, sbtf6);
   UpdateLaolLines(g_bull_intra_laol, g_bull_intra_laol_count, false, cur_low, bt7, btf7, ibt7, ibtf7, sbt7, sbtf7);
   if(ibt6 > 0) { last_bear_intra_laol_break_time = ibt6; last_bear_intra_laol_tf = ibtf6; }
   if(ibt7 > 0) { last_bull_intra_laol_break_time = ibt7; last_bull_intra_laol_tf = ibtf7; }
   
   //--- Manage HCS boxes
   if(InpShowHCSBoxes)
   {
      ManageHCSBoxes(g_hcs_boxes_bear, g_hcs_bear_count, true);
      ManageHCSBoxes(g_hcs_boxes_bull, g_hcs_bull_count, false);
   }

   //--- Collect EM counts and LV tracking (second pass)
   int intra_bear_em_total=0, intra_bull_em_total=0;
   int entry_bear_em_forming=0, entry_bull_em_forming=0;
   int entry_bear_em_est=0, entry_bull_em_est=0;
   int entry_bear_em_ret=0, entry_bull_em_ret=0;
   int entry_bear_hcs_m1=0, entry_bull_hcs_m1=0;
   int scalp_bear_em_forming=0, scalp_bull_em_forming=0;
   int scalp_bear_em_est=0, scalp_bull_em_est=0;
   int scalp_bear_em_ret=0, scalp_bull_em_ret=0;
   int intra_bear_em_forming_cnt=0, intra_bull_em_forming_cnt=0;
   bool intra_bear_retesting=false, intra_bull_retesting=false;
   bool entry_has_est_retest_bear=false, entry_has_est_retest_bull=false;
   bool scalp_has_est_retest_bear=false, scalp_has_est_retest_bull=false;
   bool intra_has_est_retest_bear=false, intra_has_est_retest_bull=false;
   bool intra_bear_est_ret_dir_found=false, intra_bull_est_ret_dir_found=false;
   bool intra_bear_est_ret_box_found=false, intra_bull_est_ret_box_found=false;
   bool intra_bear_em_form_found=false, intra_bull_em_form_found=false;
   bool intra_bear_hcs_retesting_flag=false, intra_bull_hcs_retesting_flag=false;
   
   // Check HCS retesting in INTRA range
   for(int i = INTRA_MIN_IDX; i <= INTRA_MAX_IDX; i++)
   {
      if(arr_bear_hcs_retesting[i]) intra_bear_hcs_retesting_flag = true;
      if(arr_bull_hcs_retesting[i]) intra_bull_hcs_retesting_flag = true;
   }
   
   for(int i = 0; i < TF_COUNT; i++)
   {
      string tf_category2 = TF_CATEGORIES[i];
      if(tf_category2 == "NONE") continue;
      
      bool i_conf2 = arr_tf_conf[i];
      double i_h2 = arr_tf_h[i];
      double i_l2 = arr_tf_l[i];
      bool i_third_bear2 = arr_third_bear[i];
      bool i_third_bull2 = arr_third_bull[i];
      bool i_first_bear2 = arr_first_bear[i];
      bool i_first_bull2 = arr_first_bull[i];
      bool i_laol_bear2 = arr_laol_bear[i];
      bool i_laol_bull2 = arr_laol_bull[i];
      bool i_sn_bear2 = arr_sn_bear[i];
      bool i_sn_bull2 = arr_sn_bull[i];
      bool bear_hcs2 = arr_bear_hcs[i];
      bool bull_hcs2 = arr_bull_hcs[i];
      bool bear_hcs_forming2 = arr_bear_hcs_forming[i];
      bool bull_hcs_forming2 = arr_bull_hcs_forming[i];
      bool bear_tbe2 = (arr_bear_seq[i].step == 5);
      bool bull_tbe2 = (arr_bull_seq[i].step == 5);
      
      bool sn_dbl_bear2 = i_sn_bear2 && (tf_category2 == "ENTRY" ? entry_sn_bear_count >= 2 :
                           tf_category2 == "SCALP" ? scalp_sn_bear_count >= 2 : intra_sn_bear_count >= 2);
      bool sn_dbl_bull2 = i_sn_bull2 && (tf_category2 == "ENTRY" ? entry_sn_bull_count >= 2 :
                           tf_category2 == "SCALP" ? scalp_sn_bull_count >= 2 : intra_sn_bull_count >= 2);
      
      bool bear_is_em = i_third_bear2 || i_first_bear2 || i_laol_bear2 || sn_dbl_bear2 || bear_tbe2 || bear_hcs2 || bear_hcs_forming2;
      bool bull_is_em = i_third_bull2 || i_first_bull2 || i_laol_bull2 || sn_dbl_bull2 || bull_tbe2 || bull_hcs2 || bull_hcs_forming2;
      
      // Count forming EMs (unconfirmed)
      if(!i_conf2)
      {
         if(tf_category2 == "ENTRY")
         {
            if(bear_is_em) entry_bear_em_forming++;
            if(bull_is_em) entry_bull_em_forming++;
         }
         else if(tf_category2 == "SCALP")
         {
            if(bear_is_em) scalp_bear_em_forming++;
            if(bull_is_em) scalp_bull_em_forming++;
         }
         else if(tf_category2 == "INTRA")
         {
            if(bear_is_em) intra_bear_em_forming_cnt++;
            if(bull_is_em) intra_bull_em_forming_cnt++;
         }
      }
      
      // Scan boxes for EM counts, retesting, LV updates
      for(int b = 0; b < g_tf_box_count[i]; b++)
      {
         if(!g_tf_boxes[i][b].active) continue;
         bool is_em = IsEMPattern(g_tf_boxes[i][b].base_pattern);
         bool is_fu_sn = IsFUPattern(g_tf_boxes[i][b].base_pattern);
         bool should_check = (tf_category2 == "SCALP") ? (is_em || is_fu_sn) : is_em;
         if(!should_check) continue;
         
         bool is_active = (g_tf_boxes[i][b].state == STATE_FORMING ||
                          g_tf_boxes[i][b].state == STATE_ESTABLISHED ||
                          g_tf_boxes[i][b].state == STATE_EST_RETEST ||
                          g_tf_boxes[i][b].state == STATE_RESPECTED);
         if(!is_active) continue;
         
         bool has_em_modifier = StrContains(g_tf_boxes[i][b].base_pattern, "Third") ||
                               StrContains(g_tf_boxes[i][b].base_pattern, "First") ||
                               StrContains(g_tf_boxes[i][b].base_pattern, "LAOL") ||
                               StrContains(g_tf_boxes[i][b].base_pattern, "[EM]") ||
                               StrContains(g_tf_boxes[i][b].base_pattern, "TBE") ||
                               StrContains(g_tf_boxes[i][b].base_pattern, "HCS");
         
         bool bear_touching = (g_tf_boxes[i][b].direction == "bear" && i_h2 > 0 &&
                              i_h2 >= g_tf_boxes[i][b].bottom_val && i_h2 <= g_tf_boxes[i][b].top_val);
         bool bull_touching = (g_tf_boxes[i][b].direction == "bull" && i_l2 > 0 &&
                              i_l2 <= g_tf_boxes[i][b].top_val && i_l2 >= g_tf_boxes[i][b].bottom_val);
         
         if(g_tf_boxes[i][b].direction == "bear")
         {
            if(tf_category2 == "ENTRY")
            {
               if(is_active && is_em) entry_bear_em_est++;
               if(bear_touching && g_tf_boxes[i][b].state != STATE_EST_RETEST && g_tf_boxes[i][b].state != STATE_FORMING)
                  entry_bear_em_ret++;
               if(is_em && has_em_modifier && g_tf_boxes[i][b].state == STATE_ESTABLISHED &&
                  g_tf_boxes[i][b].creation_time > entry_bear_lv.est_time)
               {
                  entry_bear_lv.pattern_text = "[" + TF_LABELS[i] + "] " + g_tf_boxes[i][b].pattern_text;
                  entry_bear_lv.original_text = entry_bear_lv.pattern_text;
                  entry_bear_lv.level = g_tf_boxes[i][b].original_top;
                  entry_bear_lv.est_time = g_tf_boxes[i][b].creation_time;
                  entry_bear_lv.direction = "bear";
                  entry_bear_lv.is_broken = false;
               }
            }
            else if(tf_category2 == "SCALP")
            {
               if(is_active && is_em) scalp_bear_em_est++;
               if(bear_touching && (is_em || is_fu_sn) && g_tf_boxes[i][b].state != STATE_EST_RETEST && g_tf_boxes[i][b].state != STATE_FORMING)
                  scalp_bear_em_ret++;
               if(is_em && has_em_modifier && g_tf_boxes[i][b].state == STATE_ESTABLISHED &&
                  g_tf_boxes[i][b].creation_time > scalp_bear_lv.est_time)
               {
                  scalp_bear_lv.pattern_text = "[" + TF_LABELS[i] + "] " + g_tf_boxes[i][b].pattern_text;
                  scalp_bear_lv.original_text = scalp_bear_lv.pattern_text;
                  scalp_bear_lv.level = g_tf_boxes[i][b].original_top;
                  scalp_bear_lv.est_time = g_tf_boxes[i][b].creation_time;
                  scalp_bear_lv.direction = "bear";
                  scalp_bear_lv.is_broken = false;
               }
            }
            else if(tf_category2 == "INTRA")
            {
               if(is_active && is_em) intra_bear_em_total++;
               if(bear_touching && is_em && g_tf_boxes[i][b].state != STATE_EST_RETEST && g_tf_boxes[i][b].state != STATE_FORMING)
                  intra_bear_retesting = true;
               if(is_em && has_em_modifier && g_tf_boxes[i][b].state == STATE_ESTABLISHED &&
                  g_tf_boxes[i][b].creation_time > intra_bear_lv.est_time)
               {
                  intra_bear_lv.pattern_text = "[" + TF_LABELS[i] + "] " + g_tf_boxes[i][b].pattern_text;
                  intra_bear_lv.original_text = intra_bear_lv.pattern_text;
                  intra_bear_lv.level = g_tf_boxes[i][b].original_top;
                  intra_bear_lv.est_time = g_tf_boxes[i][b].creation_time;
                  intra_bear_lv.direction = "bear";
                  intra_bear_lv.is_broken = false;
               }
               if(g_tf_boxes[i][b].has_est_retest &&
                  (g_tf_boxes[i][b].state == STATE_EST_RETEST ||
                   (g_tf_boxes[i][b].state == STATE_RESPECTED && g_tf_boxes[i][b].completed_est_retest)))
                  intra_bear_est_ret_box_found = true;
               if(g_tf_boxes[i][b].is_em_forming &&
                  (g_tf_boxes[i][b].state == STATE_FORMING || g_tf_boxes[i][b].state == STATE_ESTABLISHED))
                  intra_bear_em_form_found = true;
            }
         }
         else if(g_tf_boxes[i][b].direction == "bull")
         {
            if(tf_category2 == "ENTRY")
            {
               if(is_active && is_em) entry_bull_em_est++;
               if(bull_touching && g_tf_boxes[i][b].state != STATE_EST_RETEST && g_tf_boxes[i][b].state != STATE_FORMING)
                  entry_bull_em_ret++;
               if(is_em && has_em_modifier && g_tf_boxes[i][b].state == STATE_ESTABLISHED &&
                  g_tf_boxes[i][b].creation_time > entry_bull_lv.est_time)
               {
                  entry_bull_lv.pattern_text = "[" + TF_LABELS[i] + "] " + g_tf_boxes[i][b].pattern_text;
                  entry_bull_lv.original_text = entry_bull_lv.pattern_text;
                  entry_bull_lv.level = g_tf_boxes[i][b].original_bottom;
                  entry_bull_lv.est_time = g_tf_boxes[i][b].creation_time;
                  entry_bull_lv.direction = "bull";
                  entry_bull_lv.is_broken = false;
               }
            }
            else if(tf_category2 == "SCALP")
            {
               if(is_active && is_em) scalp_bull_em_est++;
               if(bull_touching && (is_em || is_fu_sn) && g_tf_boxes[i][b].state != STATE_EST_RETEST && g_tf_boxes[i][b].state != STATE_FORMING)
                  scalp_bull_em_ret++;
               if(is_em && has_em_modifier && g_tf_boxes[i][b].state == STATE_ESTABLISHED &&
                  g_tf_boxes[i][b].creation_time > scalp_bull_lv.est_time)
               {
                  scalp_bull_lv.pattern_text = "[" + TF_LABELS[i] + "] " + g_tf_boxes[i][b].pattern_text;
                  scalp_bull_lv.original_text = scalp_bull_lv.pattern_text;
                  scalp_bull_lv.level = g_tf_boxes[i][b].original_bottom;
                  scalp_bull_lv.est_time = g_tf_boxes[i][b].creation_time;
                  scalp_bull_lv.direction = "bull";
                  scalp_bull_lv.is_broken = false;
               }
            }
            else if(tf_category2 == "INTRA")
            {
               if(is_active && is_em) intra_bull_em_total++;
               if(bull_touching && is_em && g_tf_boxes[i][b].state != STATE_EST_RETEST && g_tf_boxes[i][b].state != STATE_FORMING)
                  intra_bull_retesting = true;
               if(is_em && has_em_modifier && g_tf_boxes[i][b].state == STATE_ESTABLISHED &&
                  g_tf_boxes[i][b].creation_time > intra_bull_lv.est_time)
               {
                  intra_bull_lv.pattern_text = "[" + TF_LABELS[i] + "] " + g_tf_boxes[i][b].pattern_text;
                  intra_bull_lv.original_text = intra_bull_lv.pattern_text;
                  intra_bull_lv.level = g_tf_boxes[i][b].original_bottom;
                  intra_bull_lv.est_time = g_tf_boxes[i][b].creation_time;
                  intra_bull_lv.direction = "bull";
                  intra_bull_lv.is_broken = false;
               }
               if(g_tf_boxes[i][b].has_est_retest &&
                  (g_tf_boxes[i][b].state == STATE_EST_RETEST ||
                   (g_tf_boxes[i][b].state == STATE_RESPECTED && g_tf_boxes[i][b].completed_est_retest)))
                  intra_bull_est_ret_box_found = true;
               if(g_tf_boxes[i][b].is_em_forming &&
                  (g_tf_boxes[i][b].state == STATE_FORMING || g_tf_boxes[i][b].state == STATE_ESTABLISHED))
                  intra_bull_em_form_found = true;
            }
         }
      }
      
      // EST retest tracking per category
      if(tf_category2 == "ENTRY")
      {
         if(arr_bear_est_retest[i]) intra_bear_est_ret_dir_found = true;
         if(arr_bull_est_retest[i]) intra_bull_est_ret_dir_found = true;
         if(arr_bear_est_retest_VALID[i]) entry_has_est_retest_bear = true;
         if(arr_bull_est_retest_VALID[i]) entry_has_est_retest_bull = true;
      }
      else if(tf_category2 == "SCALP")
      {
         if(arr_bear_est_retest_VALID[i]) scalp_has_est_retest_bear = true;
         if(arr_bull_est_retest_VALID[i]) scalp_has_est_retest_bull = true;
      }
      else if(tf_category2 == "INTRA")
      {
         if(arr_bear_est_retest[i]) intra_bear_est_ret_dir_found = true;
         if(arr_bull_est_retest[i]) intra_bull_est_ret_dir_found = true;
         if(arr_bear_est_retest_VALID[i]) intra_has_est_retest_bear = true;
         if(arr_bull_est_retest_VALID[i]) intra_has_est_retest_bull = true;
      }
   }

   //--- Check LV breaks
   CheckLVBreak(entry_bear_lv, cur_high, cur_low);
   CheckLVBreak(entry_bull_lv, cur_high, cur_low);
   CheckLVBreak(scalp_bear_lv, cur_high, cur_low);
   CheckLVBreak(scalp_bull_lv, cur_high, cur_low);
   CheckLVBreak(intra_bear_lv, cur_high, cur_low);
   CheckLVBreak(intra_bull_lv, cur_high, cur_low);
   
   //--- Resolve last valid
   string entry_lv_text, entry_lv_dir, entry_lv_orig_dir;
   bool entry_lv_broken;
   ResolveLV(entry_bear_lv, entry_bull_lv, entry_lv_text, entry_lv_dir, entry_lv_orig_dir, entry_lv_broken);
   
   string scalp_lv_text, scalp_lv_dir, scalp_lv_orig_dir;
   bool scalp_lv_broken;
   ResolveLV(scalp_bear_lv, scalp_bull_lv, scalp_lv_text, scalp_lv_dir, scalp_lv_orig_dir, scalp_lv_broken);
   
   string intra_lv_text, intra_lv_dir, intra_lv_orig_dir;
   bool intra_lv_broken;
   ResolveLV(intra_bear_lv, intra_bull_lv, intra_lv_text, intra_lv_dir, intra_lv_orig_dir, intra_lv_broken);
   
   //--- Negation detection
   intra_bear_negating = false;
   intra_bull_negating = false;
   intra_bear_negating_pattern = "";
   intra_bull_negating_pattern = "";
   
   bool check_bear_neg = (intra_lv_dir == "bull" && !intra_lv_broken);
   bool check_bull_neg = (intra_lv_dir == "bear" && !intra_lv_broken);
   
   if(check_bear_neg || check_bull_neg)
   {
      for(int i = INTRA_MIN_IDX; i <= INTRA_MAX_IDX; i++)
      {
         if(intra_bear_negating && intra_bull_negating) break;
         
         bool i_conf3 = arr_tf_conf[i];
         
         if(check_bear_neg && !intra_bear_negating)
         {
            bool i_third_bear3 = arr_third_bear[i];
            bool i_first_bear3 = arr_first_bear[i];
            bool i_laol_bear3 = arr_laol_bear[i];
            bool i_sn_bear3 = arr_sn_bear[i];
            bool i_bear_hcs3 = arr_bear_hcs[i];
            bool i_bear_hcs_forming3 = arr_bear_hcs_forming[i];
            bool bear_tbe3 = (arr_bear_seq[i].step == 5);
            bool sn_dbl_bear3 = i_sn_bear3 && (intra_sn_bear_count >= 2);
            
            bool bear_em_detected = i_third_bear3 || i_first_bear3 || i_laol_bear3 ||
                                   sn_dbl_bear3 || bear_tbe3 || i_bear_hcs3 || i_bear_hcs_forming3;
            if(bear_em_detected)
            {
               intra_bear_negating = true;
               string bp = BuildPatternStr(true, i_third_bear3, i_first_bear3, i_laol_bear3,
                                          i_sn_bear3, sn_dbl_bear3, false, bear_tbe3, i_bear_hcs3, i_bear_hcs_forming3);
               string conf_status = i_conf3 ? "" : " [FORMING]";
               intra_bear_negating_pattern = "[" + TF_LABELS[i] + "] " + bp + conf_status;
            }
         }
         
         if(check_bull_neg && !intra_bull_negating)
         {
            bool i_third_bull3 = arr_third_bull[i];
            bool i_first_bull3 = arr_first_bull[i];
            bool i_laol_bull3 = arr_laol_bull[i];
            bool i_sn_bull3 = arr_sn_bull[i];
            bool i_bull_hcs3 = arr_bull_hcs[i];
            bool i_bull_hcs_forming3 = arr_bull_hcs_forming[i];
            bool bull_tbe3 = (arr_bull_seq[i].step == 5);
            bool sn_dbl_bull3 = i_sn_bull3 && (intra_sn_bull_count >= 2);
            
            bool bull_em_detected = i_third_bull3 || i_first_bull3 || i_laol_bull3 ||
                                   sn_dbl_bull3 || bull_tbe3 || i_bull_hcs3 || i_bull_hcs_forming3;
            if(bull_em_detected)
            {
               intra_bull_negating = true;
               string bp2 = BuildPatternStr(false, i_third_bull3, i_first_bull3, i_laol_bull3,
                                           i_sn_bull3, sn_dbl_bull3, false, bull_tbe3, i_bull_hcs3, i_bull_hcs_forming3);
               string conf_status2 = i_conf3 ? "" : " [FORMING]";
               intra_bull_negating_pattern = "[" + TF_LABELS[i] + "] " + bp2 + conf_status2;
            }
         }
      }
   }

   //--- S1-S4 Base signal calculation
   bool m1_conf = arr_tf_conf[0];
   
   bool bear_base_s1=false, bear_base_s2=false, bear_base_s3=false, bear_base_s4=false;
   bool bear_base_valid=false;
   string bear_base_type="";
   
   if(entry_lv_dir == "bear" && !entry_lv_broken && scalp_lv_dir == "bear" && !scalp_lv_broken)
   {
      int scalp_bear_total = scalp_bear_em_est + scalp_bear_em_forming;
      int entry_bear_total = entry_bear_em_est + entry_bear_em_forming;
      bear_base_s1 = (scalp_bear_total > 0 && entry_bear_total > 0 && entry_bear_em_ret > 0);
      bear_base_s2 = (scalp_bear_total > 0 && scalp_bear_em_ret > 0 && entry_bear_total > 0 && entry_bear_em_ret > 0);
      bear_base_s3 = (scalp_bear_em_forming >= 1 && entry_bear_total > 0 && entry_bear_em_ret > 0);
      bear_base_s4 = (entry_bear_hcs_m1 >= 1);
      bear_base_valid = bear_base_s1 || bear_base_s2 || bear_base_s3 || bear_base_s4;
      
      if(bear_base_s4)
         bear_base_type = "S4";
      else
      {
         bear_base_type = "";
         if(bear_base_s1) bear_base_type = "S1";
         if(bear_base_s2) bear_base_type = (bear_base_type == "") ? "S2" : bear_base_type + "+S2";
         if(bear_base_s3) bear_base_type = (bear_base_type == "") ? "S3" : bear_base_type + "+S3";
      }
   }
   
   bool bull_base_s1=false, bull_base_s2=false, bull_base_s3=false, bull_base_s4=false;
   bool bull_base_valid=false;
   string bull_base_type="";
   
   if(entry_lv_dir == "bull" && !entry_lv_broken && scalp_lv_dir == "bull" && !scalp_lv_broken)
   {
      int scalp_bull_total = scalp_bull_em_est + scalp_bull_em_forming;
      int entry_bull_total = entry_bull_em_est + entry_bull_em_forming;
      bull_base_s1 = (scalp_bull_total > 0 && entry_bull_total > 0 && entry_bull_em_ret > 0);
      bull_base_s2 = (scalp_bull_total > 0 && scalp_bull_em_ret > 0 && entry_bull_total > 0 && entry_bull_em_ret > 0);
      bull_base_s3 = (scalp_bull_em_forming >= 1 && entry_bull_total > 0 && entry_bull_em_ret > 0);
      bull_base_s4 = (entry_bull_hcs_m1 >= 1);
      bull_base_valid = bull_base_s1 || bull_base_s2 || bull_base_s3 || bull_base_s4;
      
      if(bull_base_s4)
         bull_base_type = "S4";
      else
      {
         bull_base_type = "";
         if(bull_base_s1) bull_base_type = "S1";
         if(bull_base_s2) bull_base_type = (bull_base_type == "") ? "S2" : bull_base_type + "+S2";
         if(bull_base_s3) bull_base_type = (bull_base_type == "") ? "S3" : bull_base_type + "+S3";
      }
   }
   
   //--- INTRA alignment conditions
   bool bear_has_base_foundation = false;
   if(entry_lv_dir == "bear" && !entry_lv_broken && scalp_lv_dir == "bear" && !scalp_lv_broken)
   {
      int sbt2 = scalp_bear_em_est + scalp_bear_em_forming;
      int ebt2 = entry_bear_em_est + entry_bear_em_forming;
      bear_has_base_foundation = (sbt2 > 0 && ebt2 > 0 && entry_bear_em_ret > 0) ||
                                 (sbt2 > 0 && scalp_bear_em_ret > 0 && ebt2 > 0 && entry_bear_em_ret > 0) ||
                                 (scalp_bear_em_forming >= 1 && ebt2 > 0 && entry_bear_em_ret > 0) ||
                                 (entry_bear_hcs_m1 >= 1);
   }
   
   bool bear_intra_est_valid=false, bear_intra_em_valid=false;
   bool bear_intra_lv_valid=false, bear_intra_neg_valid=false, bear_zone_valid=false;
   
   if(bear_has_base_foundation)
   {
      bear_intra_est_valid = (intra_lv_dir == "bear" && !intra_lv_broken && intra_bear_est_ret_dir_found && intra_bear_est_ret_box_found);
      bear_intra_em_valid = (intra_lv_dir == "bear" && !intra_lv_broken && intra_bear_em_form_found);
      bear_intra_lv_valid = (intra_lv_dir == "bear" && !intra_lv_broken);
      bool bear_neg_hcs_condition = intra_bear_hcs_retesting_flag || intra_bull_hcs_retesting_flag ||
                                   (intra_bear_em_form_found && StrContains(intra_bear_negating_pattern, "HCS"));
      bear_intra_neg_valid = (intra_lv_orig_dir == "bull" && !intra_lv_broken && intra_bear_negating && bear_neg_hcs_condition);
      bear_zone_valid = (intra_bear_hcs_retesting_flag && intra_bear_negating);
   }
   
   bool bull_has_base_foundation = false;
   if(entry_lv_dir == "bull" && !entry_lv_broken && scalp_lv_dir == "bull" && !scalp_lv_broken)
   {
      int sbt3 = scalp_bull_em_est + scalp_bull_em_forming;
      int ebt3 = entry_bull_em_est + entry_bull_em_forming;
      bull_has_base_foundation = (sbt3 > 0 && ebt3 > 0 && entry_bull_em_ret > 0) ||
                                 (sbt3 > 0 && scalp_bull_em_ret > 0 && ebt3 > 0 && entry_bull_em_ret > 0) ||
                                 (scalp_bull_em_forming >= 1 && ebt3 > 0 && entry_bull_em_ret > 0) ||
                                 (entry_bull_hcs_m1 >= 1);
   }
   
   bool bull_intra_est_valid=false, bull_intra_em_valid=false;
   bool bull_intra_lv_valid=false, bull_intra_neg_valid=false, bull_zone_valid=false;
   
   if(bull_has_base_foundation)
   {
      bull_intra_est_valid = (intra_lv_dir == "bull" && !intra_lv_broken && intra_bull_est_ret_dir_found && intra_bull_est_ret_box_found);
      bull_intra_em_valid = (intra_lv_dir == "bull" && !intra_lv_broken && intra_bull_em_form_found);
      bull_intra_lv_valid = (intra_lv_dir == "bull" && !intra_lv_broken);
      bool bull_neg_hcs_condition = intra_bear_hcs_retesting_flag || intra_bull_hcs_retesting_flag ||
                                   (intra_bull_em_form_found && StrContains(intra_bull_negating_pattern, "HCS"));
      bull_intra_neg_valid = (intra_lv_orig_dir == "bear" && !intra_lv_broken && intra_bull_negating && bull_neg_hcs_condition);
      bull_zone_valid = (intra_bull_hcs_retesting_flag && intra_bull_negating);
   }

   //--- Forming/Confirmed signals
   bool bear_base_forming = bear_base_valid && !m1_conf && InpShowSetupsS1S4;
   bool bear_base_confirmed = bear_base_valid && m1_conf && InpShowSetupsS1S4;
   bool bear_intra_est_forming = bear_intra_est_valid && !m1_conf && InpShowIntraEstRetest;
   bool bear_intra_est_confirmed = bear_intra_est_valid && m1_conf && InpShowIntraEstRetest;
   bool bear_intra_em_forming2 = bear_intra_em_valid && !m1_conf && InpShowIntraEMForming;
   bool bear_intra_em_confirmed = bear_intra_em_valid && m1_conf && InpShowIntraEMForming;
   bool bear_intra_lv_forming = bear_intra_lv_valid && !m1_conf && InpShowIntraLVAligned;
   bool bear_intra_lv_confirmed = bear_intra_lv_valid && m1_conf && InpShowIntraLVAligned;
   bool bear_intra_neg_forming = bear_intra_neg_valid && !m1_conf && InpShowIntraNegation;
   bool bear_intra_neg_confirmed = bear_intra_neg_valid && m1_conf && InpShowIntraNegation;
   bool bear_zone_forming = bear_zone_valid && !m1_conf && InpShowIntraNegation;
   bool bear_zone_confirmed = bear_zone_valid && m1_conf && InpShowIntraNegation;
   
   bool bull_base_forming = bull_base_valid && !m1_conf && InpShowSetupsS1S4;
   bool bull_base_confirmed = bull_base_valid && m1_conf && InpShowSetupsS1S4;
   bool bull_intra_est_forming = bull_intra_est_valid && !m1_conf && InpShowIntraEstRetest;
   bool bull_intra_est_confirmed = bull_intra_est_valid && m1_conf && InpShowIntraEstRetest;
   bool bull_intra_em_forming2 = bull_intra_em_valid && !m1_conf && InpShowIntraEMForming;
   bool bull_intra_em_confirmed = bull_intra_em_valid && m1_conf && InpShowIntraEMForming;
   bool bull_intra_lv_forming = bull_intra_lv_valid && !m1_conf && InpShowIntraLVAligned;
   bool bull_intra_lv_confirmed = bull_intra_lv_valid && m1_conf && InpShowIntraLVAligned;
   bool bull_intra_neg_forming = bull_intra_neg_valid && !m1_conf && InpShowIntraNegation;
   bool bull_intra_neg_confirmed = bull_intra_neg_valid && m1_conf && InpShowIntraNegation;
   bool bull_zone_forming = bull_zone_valid && !m1_conf && InpShowIntraNegation;
   bool bull_zone_confirmed = bull_zone_valid && m1_conf && InpShowIntraNegation;
   
   bool bear_has_any_intra = bear_zone_forming || bear_zone_confirmed || bear_intra_neg_forming ||
      bear_intra_neg_confirmed || bear_intra_lv_forming || bear_intra_lv_confirmed ||
      bear_intra_em_forming2 || bear_intra_em_confirmed || bear_intra_est_forming || bear_intra_est_confirmed;
   bool bull_has_any_intra = bull_zone_forming || bull_zone_confirmed || bull_intra_neg_forming ||
      bull_intra_neg_confirmed || bull_intra_lv_forming || bull_intra_lv_confirmed ||
      bull_intra_em_forming2 || bull_intra_em_confirmed || bull_intra_est_forming || bull_intra_est_confirmed;

   //--- RR Box generation: BEAR FORMING
   string bear_ft = "";
   bool bear_has_any_intra_alert = bear_zone_forming || bear_intra_neg_forming || bear_intra_lv_forming ||
      bear_intra_em_forming2 || bear_intra_est_forming;
   
   if(bear_zone_forming) bear_ft = "INTRA+ZONE [" + bear_base_type + "]";
   else if(bear_intra_neg_forming) bear_ft = "INTRA+NEG [" + bear_base_type + "]";
   else if(bear_intra_lv_forming) bear_ft = "INTRA+LV [" + bear_base_type + "]";
   else if(bear_intra_em_forming2) bear_ft = "INTRA+EM [" + bear_base_type + "]";
   else if(bear_intra_est_forming) bear_ft = "INTRA+EST+RET [" + bear_base_type + "]";
   else if(bear_base_forming && !bear_has_any_intra_alert) bear_ft = bear_base_type;
   
   int bar_idx = GetBarIndex();
   
   if(bear_ft != "" && (bear_forming_rr_bar < 0 || bar_idx != bear_forming_rr_bar || bear_ft != bear_forming_type_prev))
   {
      // Delete old forming
      DeleteFormingRR(bear_forming_rr_sl_name, bear_forming_rr_tp_name, bear_forming_rr_pip_name, bear_forming_rr_bar);
      
      double f_entry = MathMax(open[0], close[0]);
      double f_sl = high[0];
      double f_ext_sl = FindNextExtremeCandle("bear", f_sl);
      if(f_ext_sl > 0 && f_ext_sl > f_entry) f_sl = f_ext_sl;
      double f_range = f_sl - f_entry;
      double f_tp = f_entry - (f_range * InpTPMultiplier);
      double f_40pip = f_entry - (InpPipTarget * pip_value);
      
      // Create bear forming SL box (top=sl, bottom=entry)
      CreateRRBoxVisual(bear_forming_rr_sl_name, bear_forming_rr_tp_name, bear_forming_rr_pip_name,
                       f_sl, f_entry, f_tp, f_40pip, bear_ft, true);
      bear_forming_rr_bar = bar_idx;
      bear_forming_type_prev = bear_ft;
      
      Alert("BEAR FORMING | SL=" + DoubleToString(f_sl, _Digits) + " | Entry=" + DoubleToString(f_entry, _Digits));
      SendNotification("BEAR FORMING | " + bear_ft);
   }
   bear_forming_type = bear_ft;

   //--- RR Box generation: BEAR CONFIRMED
   bool bear_confirmed_triggered = false;
   string bear_confirmed_type = "";
   bool bear_has_any_intra_confirmed = bear_zone_confirmed || bear_intra_neg_confirmed ||
      bear_intra_lv_confirmed || bear_intra_em_confirmed || bear_intra_est_confirmed;
   
   if(bear_zone_confirmed) { bear_confirmed_type = "INTRA+ZONE [" + bear_base_type + "]"; bear_confirmed_triggered = true; }
   else if(bear_intra_neg_confirmed) { bear_confirmed_type = "INTRA+NEG [" + bear_base_type + "]"; bear_confirmed_triggered = true; }
   else if(bear_intra_lv_confirmed) { bear_confirmed_type = "INTRA+LV [" + bear_base_type + "]"; bear_confirmed_triggered = true; }
   else if(bear_intra_em_confirmed) { bear_confirmed_type = "INTRA+EM [" + bear_base_type + "]"; bear_confirmed_triggered = true; }
   else if(bear_intra_est_confirmed) { bear_confirmed_type = "INTRA+EST+RET [" + bear_base_type + "]"; bear_confirmed_triggered = true; }
   else if(bear_base_confirmed && !bear_has_any_intra_confirmed) { bear_confirmed_type = bear_base_type; bear_confirmed_triggered = true; }
   
   if(bear_confirmed_triggered)
   {
      DeleteFormingRR(bear_forming_rr_sl_name, bear_forming_rr_tp_name, bear_forming_rr_pip_name, bear_forming_rr_bar);
      
      double bear_entry = MathMax(open[0], close[0]);
      double bear_sl = high[0];
      double ext_sl = FindNextExtremeCandle("bear", bear_sl);
      if(ext_sl > 0 && ext_sl > bear_entry) bear_sl = ext_sl;
      double box_range = bear_sl - bear_entry;
      double bear_tp = bear_entry - (box_range * InpTPMultiplier);
      double target_40pip = bear_entry - (InpPipTarget * pip_value);
      
      if(g_rr_bear_count < MAX_RR_BOXES)
      {
         int ri = g_rr_bear_count;
         CreateRRBoxVisual(g_rr_boxes_bear[ri].sl_obj_name, g_rr_boxes_bear[ri].tp_obj_name,
                          g_rr_boxes_bear[ri].pip_obj_name,
                          bear_sl, bear_entry, bear_tp, target_40pip, bear_confirmed_type, false);
         g_rr_boxes_bear[ri].direction = "bear";
         g_rr_boxes_bear[ri].sl_level = bear_sl;
         g_rr_boxes_bear[ri].creation_bar = bar_idx;
         g_rr_boxes_bear[ri].active = true;
         g_rr_bear_count++;
      }
      Alert("BEAR CONFIRMED | SL=" + DoubleToString(bear_sl, _Digits) + " | Entry=" + DoubleToString(bear_entry, _Digits));
      SendNotification("BEAR CONFIRMED | " + bear_confirmed_type);
   }
   
   //--- RR Box generation: BULL FORMING
   string bull_ft = "";
   bool bull_has_any_intra_alert = bull_zone_forming || bull_intra_neg_forming || bull_intra_lv_forming ||
      bull_intra_em_forming2 || bull_intra_est_forming;
   
   if(bull_zone_forming) bull_ft = "INTRA+ZONE [" + bull_base_type + "]";
   else if(bull_intra_neg_forming) bull_ft = "INTRA+NEG [" + bull_base_type + "]";
   else if(bull_intra_lv_forming) bull_ft = "INTRA+LV [" + bull_base_type + "]";
   else if(bull_intra_em_forming2) bull_ft = "INTRA+EM [" + bull_base_type + "]";
   else if(bull_intra_est_forming) bull_ft = "INTRA+EST+RET [" + bull_base_type + "]";
   else if(bull_base_forming && !bull_has_any_intra_alert) bull_ft = bull_base_type;
   
   if(bull_ft != "" && (bull_forming_rr_bar < 0 || bar_idx != bull_forming_rr_bar || bull_ft != bull_forming_type_prev))
   {
      DeleteFormingRR(bull_forming_rr_sl_name, bull_forming_rr_tp_name, bull_forming_rr_pip_name, bull_forming_rr_bar);
      
      double f_entry2 = MathMin(open[0], close[0]);
      double f_sl2 = low[0];
      double f_ext_sl2 = FindNextExtremeCandle("bull", f_sl2);
      if(f_ext_sl2 > 0 && f_ext_sl2 < f_entry2) f_sl2 = f_ext_sl2;
      double f_range2 = f_entry2 - f_sl2;
      double f_tp2 = f_entry2 + (f_range2 * InpTPMultiplier);
      double f_40pip2 = f_entry2 + (InpPipTarget * pip_value);
      
      // For bull: SL is below entry, TP is above
      CreateRRBoxVisual(bull_forming_rr_sl_name, bull_forming_rr_tp_name, bull_forming_rr_pip_name,
                       f_entry2, f_sl2, f_tp2, f_40pip2, bull_ft, true);
      bull_forming_rr_bar = bar_idx;
      bull_forming_type_prev = bull_ft;
      
      Alert("BULL FORMING | SL=" + DoubleToString(f_sl2, _Digits) + " | Entry=" + DoubleToString(f_entry2, _Digits));
      SendNotification("BULL FORMING | " + bull_ft);
   }
   bull_forming_type = bull_ft;
   
   //--- RR Box generation: BULL CONFIRMED
   bool bull_confirmed_triggered = false;
   string bull_confirmed_type = "";
   bool bull_has_any_intra_confirmed = bull_zone_confirmed || bull_intra_neg_confirmed ||
      bull_intra_lv_confirmed || bull_intra_em_confirmed || bull_intra_est_confirmed;
   
   if(bull_zone_confirmed) { bull_confirmed_type = "INTRA+ZONE [" + bull_base_type + "]"; bull_confirmed_triggered = true; }
   else if(bull_intra_neg_confirmed) { bull_confirmed_type = "INTRA+NEG [" + bull_base_type + "]"; bull_confirmed_triggered = true; }
   else if(bull_intra_lv_confirmed) { bull_confirmed_type = "INTRA+LV [" + bull_base_type + "]"; bull_confirmed_triggered = true; }
   else if(bull_intra_em_confirmed) { bull_confirmed_type = "INTRA+EM [" + bull_base_type + "]"; bull_confirmed_triggered = true; }
   else if(bull_intra_est_confirmed) { bull_confirmed_type = "INTRA+EST+RET [" + bull_base_type + "]"; bull_confirmed_triggered = true; }
   else if(bull_base_confirmed && !bull_has_any_intra_confirmed) { bull_confirmed_type = bull_base_type; bull_confirmed_triggered = true; }
   
   if(bull_confirmed_triggered)
   {
      DeleteFormingRR(bull_forming_rr_sl_name, bull_forming_rr_tp_name, bull_forming_rr_pip_name, bull_forming_rr_bar);
      
      double bull_entry = MathMin(open[0], close[0]);
      double bull_sl = low[0];
      double ext_sl2 = FindNextExtremeCandle("bull", bull_sl);
      if(ext_sl2 > 0 && ext_sl2 < bull_entry) bull_sl = ext_sl2;
      double box_range2 = bull_entry - bull_sl;
      double bull_tp = bull_entry + (box_range2 * InpTPMultiplier);
      double target_40pip2 = bull_entry + (InpPipTarget * pip_value);
      
      if(g_rr_bull_count < MAX_RR_BOXES)
      {
         int ri2 = g_rr_bull_count;
         CreateRRBoxVisual(g_rr_boxes_bull[ri2].sl_obj_name, g_rr_boxes_bull[ri2].tp_obj_name,
                          g_rr_boxes_bull[ri2].pip_obj_name,
                          bull_entry, bull_sl, bull_tp, target_40pip2, bull_confirmed_type, false);
         g_rr_boxes_bull[ri2].direction = "bull";
         g_rr_boxes_bull[ri2].sl_level = bull_sl;
         g_rr_boxes_bull[ri2].creation_bar = bar_idx;
         g_rr_boxes_bull[ri2].active = true;
         g_rr_bull_count++;
      }
      Alert("BULL CONFIRMED | SL=" + DoubleToString(bull_sl, _Digits) + " | Entry=" + DoubleToString(bull_entry, _Digits));
      SendNotification("BULL CONFIRMED | " + bull_confirmed_type);
   }

   //--- Final Entry signal
   // Record setup bar
   if(bear_base_valid && (final_entry_bear_setup_bar < 0 || (bar_idx - final_entry_bear_setup_bar) > 5))
   {
      final_entry_bear_setup_bar = bar_idx;
      final_entry_bear_pattern = bear_base_type;
   }
   if(bear_intra_est_valid || bear_intra_em_valid || bear_intra_lv_valid || bear_intra_neg_valid || bear_zone_valid)
   {
      if(final_entry_bear_setup_bar < 0 || (bar_idx - final_entry_bear_setup_bar) > 5)
      {
         final_entry_bear_setup_bar = bar_idx;
         // Build pattern
         string parts = "";
         if(bear_zone_valid) parts = "ZONE";
         if(bear_intra_est_valid) parts = (parts == "") ? "EST" : parts + "+EST";
         if(bear_intra_em_valid) parts = (parts == "") ? "EM" : parts + "+EM";
         if(bear_intra_lv_valid) parts = (parts == "") ? "LV" : parts + "+LV";
         if(bear_intra_neg_valid && !bear_zone_valid) parts = (parts == "") ? "NEG" : parts + "+NEG";
         final_entry_bear_pattern = "INTRA+" + parts + " [" + bear_base_type + "]";
      }
   }
   
   if(bull_base_valid && (final_entry_bull_setup_bar < 0 || (bar_idx - final_entry_bull_setup_bar) > 5))
   {
      final_entry_bull_setup_bar = bar_idx;
      final_entry_bull_pattern = bull_base_type;
   }
   if(bull_intra_est_valid || bull_intra_em_valid || bull_intra_lv_valid || bull_intra_neg_valid || bull_zone_valid)
   {
      if(final_entry_bull_setup_bar < 0 || (bar_idx - final_entry_bull_setup_bar) > 5)
      {
         final_entry_bull_setup_bar = bar_idx;
         string parts2 = "";
         if(bull_zone_valid) parts2 = "ZONE";
         if(bull_intra_est_valid) parts2 = (parts2 == "") ? "EST" : parts2 + "+EST";
         if(bull_intra_em_valid) parts2 = (parts2 == "") ? "EM" : parts2 + "+EM";
         if(bull_intra_lv_valid) parts2 = (parts2 == "") ? "LV" : parts2 + "+LV";
         if(bull_intra_neg_valid && !bull_zone_valid) parts2 = (parts2 == "") ? "NEG" : parts2 + "+NEG";
         final_entry_bull_pattern = "INTRA+" + parts2 + " [" + bull_base_type + "]";
      }
   }
   
   // Scalp FU retest check
   bool scalp_bear_fu_retest = false, scalp_bull_fu_retest = false;
   for(int i = SCALP_MIN_IDX; i <= SCALP_MAX_IDX; i++)
   {
      for(int b = 0; b < g_tf_box_count[i]; b++)
      {
         if(!g_tf_boxes[i][b].active) continue;
         if(g_tf_boxes[i][b].has_been_retested && g_tf_boxes[i][b].state != STATE_FORMING)
         {
            if(g_tf_boxes[i][b].direction == "bear" &&
               (StrContains(g_tf_boxes[i][b].pattern_text, "FU") || StrContains(g_tf_boxes[i][b].pattern_text, "SN")))
               scalp_bear_fu_retest = true;
            if(g_tf_boxes[i][b].direction == "bull" &&
               (StrContains(g_tf_boxes[i][b].pattern_text, "FU") || StrContains(g_tf_boxes[i][b].pattern_text, "SN")))
               scalp_bull_fu_retest = true;
         }
      }
   }
   
   // LAOL broken level
   double bear_laol_broken_level = GetBrokenLaolRecent(g_bear_laol, g_bear_laol_count, InpFinalEntryMultiLaol);
   double bull_laol_broken_level = GetBrokenLaolRecent(g_bull_laol, g_bull_laol_count, InpFinalEntryMultiLaol);
   
   // Final Entry conditions
   bool bear_setup_within_window = (final_entry_bear_setup_bar >= 0 && (bar_idx - final_entry_bear_setup_bar) <= 10);
   bool bull_setup_within_window = (final_entry_bull_setup_bar >= 0 && (bar_idx - final_entry_bull_setup_bar) <= 10);
   
   bool bear_has_intra_final = (InpShowFinalIntraEst && StrContains(final_entry_bear_pattern, "EST")) ||
      (InpShowFinalIntraEM && StrContains(final_entry_bear_pattern, "EM")) ||
      (InpShowFinalIntraLV && StrContains(final_entry_bear_pattern, "LV")) ||
      (InpShowFinalIntraNeg && (StrContains(final_entry_bear_pattern, "NEG") || StrContains(final_entry_bear_pattern, "ZONE")));
   
   bool final_entry_bear_base = InpShowFinalEntry && InpShowFinalS1S4 && bear_setup_within_window &&
      StrContains(final_entry_bear_pattern, "S") && !bear_has_intra_final &&
      bear_laol_broken_level > 0 && scalp_bear_fu_retest && scalp_lv_dir == "bear" && !scalp_lv_broken;
   
   bool final_entry_bear_intra_est = InpShowFinalEntry && InpShowFinalIntraEst && bear_setup_within_window &&
      StrContains(final_entry_bear_pattern, "EST") && bear_laol_broken_level > 0 &&
      scalp_bear_fu_retest && scalp_lv_dir == "bear" && !scalp_lv_broken;
   
   bool final_entry_bear_intra_em = InpShowFinalEntry && InpShowFinalIntraEM && bear_setup_within_window &&
      StrContains(final_entry_bear_pattern, "EM") && bear_laol_broken_level > 0 &&
      scalp_bear_fu_retest && scalp_lv_dir == "bear" && !scalp_lv_broken;
   
   bool final_entry_bear_intra_neg = InpShowFinalEntry && InpShowFinalIntraNeg && bear_setup_within_window &&
      (StrContains(final_entry_bear_pattern, "NEG") || StrContains(final_entry_bear_pattern, "ZONE")) &&
      bear_laol_broken_level > 0 && scalp_bear_fu_retest && scalp_lv_dir == "bear" && !scalp_lv_broken;
   
   bool final_entry_bear = final_entry_bear_base || final_entry_bear_intra_est ||
      final_entry_bear_intra_em || final_entry_bear_intra_neg;
   
   bool bull_has_intra_final = (InpShowFinalIntraEst && StrContains(final_entry_bull_pattern, "EST")) ||
      (InpShowFinalIntraEM && StrContains(final_entry_bull_pattern, "EM")) ||
      (InpShowFinalIntraLV && StrContains(final_entry_bull_pattern, "LV")) ||
      (InpShowFinalIntraNeg && (StrContains(final_entry_bull_pattern, "NEG") || StrContains(final_entry_bull_pattern, "ZONE")));
   
   bool final_entry_bull_base = InpShowFinalEntry && InpShowFinalS1S4 && bull_setup_within_window &&
      StrContains(final_entry_bull_pattern, "S") && !bull_has_intra_final &&
      bull_laol_broken_level > 0 && scalp_bull_fu_retest && scalp_lv_dir == "bull" && !scalp_lv_broken;
   
   bool final_entry_bull_intra_est = InpShowFinalEntry && InpShowFinalIntraEst && bull_setup_within_window &&
      StrContains(final_entry_bull_pattern, "EST") && bull_laol_broken_level > 0 &&
      scalp_bull_fu_retest && scalp_lv_dir == "bull" && !scalp_lv_broken;
   
   bool final_entry_bull_intra_em = InpShowFinalEntry && InpShowFinalIntraEM && bull_setup_within_window &&
      StrContains(final_entry_bull_pattern, "EM") && bull_laol_broken_level > 0 &&
      scalp_bull_fu_retest && scalp_lv_dir == "bull" && !scalp_lv_broken;
   
   bool final_entry_bull_intra_neg = InpShowFinalEntry && InpShowFinalIntraNeg && bull_setup_within_window &&
      (StrContains(final_entry_bull_pattern, "NEG") || StrContains(final_entry_bull_pattern, "ZONE")) &&
      bull_laol_broken_level > 0 && scalp_bull_fu_retest && scalp_lv_dir == "bull" && !scalp_lv_broken;
   
   bool final_entry_bull = final_entry_bull_base || final_entry_bull_intra_est ||
      final_entry_bull_intra_em || final_entry_bull_intra_neg;

   //--- Final Entry RR boxes
   if(final_entry_bear)
   {
      DeleteFormingRR(bear_forming_rr_sl_name, bear_forming_rr_tp_name, bear_forming_rr_pip_name, bear_forming_rr_bar);
      
      double be = MathMax(open[0], close[0]);
      double bs = high[0];
      double es = FindNextExtremeCandle("bear", bs);
      if(es > 0 && es > be) bs = es;
      double br = bs - be;
      double btp = be - (br * InpTPMultiplier);
      double b40 = be - (InpPipTarget * pip_value);
      
      if(g_rr_bear_count < MAX_RR_BOXES)
      {
         int ri3 = g_rr_bear_count;
         CreateRRBoxVisual(g_rr_boxes_bear[ri3].sl_obj_name, g_rr_boxes_bear[ri3].tp_obj_name,
                          g_rr_boxes_bear[ri3].pip_obj_name,
                          bs, be, btp, b40, "FINAL\n" + final_entry_bear_pattern, false);
         g_rr_boxes_bear[ri3].direction = "bear";
         g_rr_boxes_bear[ri3].sl_level = bs;
         g_rr_boxes_bear[ri3].creation_bar = bar_idx;
         g_rr_boxes_bear[ri3].active = true;
         g_rr_bear_count++;
      }
      Alert("FINAL ENTRY BEAR | SL=" + DoubleToString(bs, _Digits) + " | Entry=" + DoubleToString(be, _Digits));
      SendNotification("FINAL ENTRY BEAR | " + final_entry_bear_pattern);
   }
   
   if(final_entry_bull)
   {
      DeleteFormingRR(bull_forming_rr_sl_name, bull_forming_rr_tp_name, bull_forming_rr_pip_name, bull_forming_rr_bar);
      
      double be2 = MathMin(open[0], close[0]);
      double bs2 = low[0];
      double es2 = FindNextExtremeCandle("bull", bs2);
      if(es2 > 0 && es2 < be2) bs2 = es2;
      double br2 = be2 - bs2;
      double btp2 = be2 + (br2 * InpTPMultiplier);
      double b402 = be2 + (InpPipTarget * pip_value);
      
      if(g_rr_bull_count < MAX_RR_BOXES)
      {
         int ri4 = g_rr_bull_count;
         CreateRRBoxVisual(g_rr_boxes_bull[ri4].sl_obj_name, g_rr_boxes_bull[ri4].tp_obj_name,
                          g_rr_boxes_bull[ri4].pip_obj_name,
                          be2, bs2, btp2, b402, "FINAL\n" + final_entry_bull_pattern, false);
         g_rr_boxes_bull[ri4].direction = "bull";
         g_rr_boxes_bull[ri4].sl_level = bs2;
         g_rr_boxes_bull[ri4].creation_bar = bar_idx;
         g_rr_boxes_bull[ri4].active = true;
         g_rr_bull_count++;
      }
      Alert("FINAL ENTRY BULL | SL=" + DoubleToString(bs2, _Digits) + " | Entry=" + DoubleToString(be2, _Digits));
      SendNotification("FINAL ENTRY BULL | " + final_entry_bull_pattern);
   }
   
   //--- Manage RR boxes: delete if SL hit
   for(int i = g_rr_bear_count - 1; i >= 0; i--)
   {
      if(!g_rr_boxes_bear[i].active) continue;
      if(cur_high > g_rr_boxes_bear[i].sl_level)
      {
         if(g_rr_boxes_bear[i].sl_obj_name != "") ObjectDelete(0, g_rr_boxes_bear[i].sl_obj_name);
         if(g_rr_boxes_bear[i].tp_obj_name != "") ObjectDelete(0, g_rr_boxes_bear[i].tp_obj_name);
         if(g_rr_boxes_bear[i].pip_obj_name != "") ObjectDelete(0, g_rr_boxes_bear[i].pip_obj_name);
         // Also delete text labels
         string sn1 = g_rr_boxes_bear[i].sl_obj_name + "_txt";
         string sn2 = g_rr_boxes_bear[i].tp_obj_name + "_txt";
         if(ObjectFind(0, sn1) >= 0) ObjectDelete(0, sn1);
         if(ObjectFind(0, sn2) >= 0) ObjectDelete(0, sn2);
         // Shift array
         for(int j = i; j < g_rr_bear_count - 1; j++)
            g_rr_boxes_bear[j] = g_rr_boxes_bear[j+1];
         g_rr_bear_count--;
      }
   }
   for(int i = g_rr_bull_count - 1; i >= 0; i--)
   {
      if(!g_rr_boxes_bull[i].active) continue;
      if(cur_low < g_rr_boxes_bull[i].sl_level)
      {
         if(g_rr_boxes_bull[i].sl_obj_name != "") ObjectDelete(0, g_rr_boxes_bull[i].sl_obj_name);
         if(g_rr_boxes_bull[i].tp_obj_name != "") ObjectDelete(0, g_rr_boxes_bull[i].tp_obj_name);
         if(g_rr_boxes_bull[i].pip_obj_name != "") ObjectDelete(0, g_rr_boxes_bull[i].pip_obj_name);
         string sn3 = g_rr_boxes_bull[i].sl_obj_name + "_txt";
         string sn4 = g_rr_boxes_bull[i].tp_obj_name + "_txt";
         if(ObjectFind(0, sn3) >= 0) ObjectDelete(0, sn3);
         if(ObjectFind(0, sn4) >= 0) ObjectDelete(0, sn4);
         for(int j = i; j < g_rr_bull_count - 1; j++)
            g_rr_boxes_bull[j] = g_rr_boxes_bull[j+1];
         g_rr_bull_count--;
      }
   }

   //--- XLAOL visual management: extend lines and check hits
   for(int i = g_xlaol_count - 1; i >= 0; i--)
   {
      if(!g_xlaol[i].active) continue;
      
      // Extend line and move label
      datetime t_end = GetFutureTime(g_xlaol[i].offset);
      if(g_xlaol[i].label_name != "" && ObjectFind(0, g_xlaol[i].label_name) >= 0)
         ObjectSetInteger(0, g_xlaol[i].label_name, OBJPROP_TIME, (long)t_end);
      if(g_xlaol[i].line_name != "" && ObjectFind(0, g_xlaol[i].line_name) >= 0)
         ObjectSetInteger(0, g_xlaol[i].line_name, OBJPROP_TIME, 1, (long)t_end);
      
      // Check hit
      bool hit = g_xlaol[i].is_bear ? (cur_high > g_xlaol[i].level) : (cur_low < g_xlaol[i].level);
      if(hit)
      {
         if(g_xlaol[i].line_name != "") ObjectDelete(0, g_xlaol[i].line_name);
         if(g_xlaol[i].label_name != "") ObjectDelete(0, g_xlaol[i].label_name);
         
         // Alert on hit
         if(g_xlaol[i].category == "ENTRY")
         {
            if(g_xlaol[i].is_bear)
               Alert("ENTRY LAOL BEAR TAKEN inside box");
            else
               Alert("ENTRY LAOL BULL TAKEN inside box");
         }
         else
         {
            if(g_xlaol[i].is_bear)
               Alert("SCALP LAOL BEAR TAKEN inside INTRA box");
            else
               Alert("SCALP LAOL BULL TAKEN inside INTRA box");
         }
         
         // Remove from array
         for(int j = i; j < g_xlaol_count - 1; j++)
            g_xlaol[j] = g_xlaol[j+1];
         g_xlaol_count--;
      }
   }
   
   //--- Reset per-bar pattern flags for next calculation
   for(int i = 0; i < TF_COUNT; i++)
   {
      arr_fu_bear[i] = false;
      arr_fu_bull[i] = false;
      arr_sn_bear[i] = false;
      arr_sn_bull[i] = false;
      arr_first_bear[i] = false;
      arr_first_bull[i] = false;
      arr_second_bear[i] = false;
      arr_second_bull[i] = false;
      arr_third_bear[i] = false;
      arr_third_bull[i] = false;
      arr_laol_bear[i] = false;
      arr_laol_bull[i] = false;
      arr_bear_hcs[i] = false;
      arr_bull_hcs[i] = false;
      arr_bear_hcs_forming[i] = false;
      arr_bull_hcs_forming[i] = false;
      arr_bear_retesting[i] = false;
      arr_bull_retesting[i] = false;
      arr_bear_est_retest[i] = false;
      arr_bull_est_retest[i] = false;
      arr_bear_est_retest_VALID[i] = false;
      arr_bull_est_retest_VALID[i] = false;
      arr_bear_retest_pattern[i] = "";
      arr_bull_retest_pattern[i] = "";
      arr_bear_retest_level[i] = 0;
      arr_bull_retest_level[i] = 0;
   }
   
   ChartRedraw(0);
   return rates_total;
}
//+------------------------------------------------------------------+
