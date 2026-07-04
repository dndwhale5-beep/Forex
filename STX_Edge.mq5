//+------------------------------------------------------------------+
//|                                                     STX_Edge.mq5 |
//|                        STX Edge - Multi-Timeframe Pattern Detector|
//|                        Converted from Pine Script v6 to MQL5      |
//+------------------------------------------------------------------+
#property copyright "STX Edge"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Input parameters
input bool   InpSoftStart        = false;  // SOFT START (enable INTRA TFs 30-100)
input int    InpTPMultiplier     = 8;      // TP Multiplier
input int    InpSetupLookback    = 5;      // Setup Lookback
input double InpPipTarget        = 40.0;   // Pip Target
input int    InpLaolDeleteDelay  = 2;      // LAOL Delete Delay (bars)
input bool   InpShowFinalEntry   = true;   // Show Final Entry
input bool   InpShowFinalS1S4    = true;   // Show Final S1-S4
input bool   InpShowFinalIntraEst = true;  // Show Final Intra EST
input bool   InpShowFinalIntraEM  = true;  // Show Final Intra EM
input bool   InpShowFinalIntraLV  = false; // Show Final Intra LV
input bool   InpShowFinalIntraNeg = true;  // Show Final Intra Negation
input bool   InpFinalEntryMultiLaol = false; // Final Entry Multi LAOL
input bool   InpShowIntraEstRetest  = true;  // Show Intra EST Retest
input bool   InpShowIntraEMForming  = true;  // Show Intra EM Forming
input bool   InpShowIntraLVAligned  = false; // Show Intra LV Aligned
input bool   InpShowIntraNegation   = true;  // Show Intra Negation
input bool   InpShowHCSBoxes        = true;  // Show HCS Boxes
input bool   InpShowSetupsS1S4      = true;  // Show Setups S1-S4

//--- Constants
#define TF_COUNT 25
#define ENTRY_MIN_IDX 0
#define ENTRY_MAX_IDX 4
#define SCALP_MIN_IDX 5
#define SCALP_MAX_IDX 15
#define INTRA_MIN_IDX 16
#define INTRA_MAX_IDX 24

//--- Timeframe definitions (in minutes)
int TF_MINUTES[TF_COUNT] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,20,30,35,40,45,50,55,60,90,100};

//--- Get MT5 timeframe enum from minutes
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
      case 7:   return PERIOD_M6; // M7 not standard, using M6
      case 8:   return PERIOD_M6; // M8 not standard, using M6
      case 9:   return PERIOD_M10; // M9 not standard, using M10
      case 10:  return PERIOD_M10;
      case 11:  return PERIOD_M10; // M11 not standard, using M10
      case 12:  return PERIOD_M12;
      case 13:  return PERIOD_M12; // M13 not standard, using M12
      case 14:  return PERIOD_M15; // M14 not standard, using M15
      case 15:  return PERIOD_M15;
      case 20:  return PERIOD_M20;
      case 30:  return PERIOD_M30;
      case 35:  return PERIOD_M30; // Approximate with M30
      case 40:  return PERIOD_M30; // Approximate with M30
      case 45:  return PERIOD_H1;  // Approximate with H1
      case 50:  return PERIOD_H1;  // Approximate with H1
      case 55:  return PERIOD_H1;  // Approximate with H1
      case 60:  return PERIOD_H1;
      case 90:  return PERIOD_H1;  // Approximate
      case 100: return PERIOD_H2;  // Approximate with H2
      default:  return PERIOD_M1;
   }
}

//--- Category enumeration
enum ENUM_TF_CATEGORY
{
   CAT_ENTRY = 0,
   CAT_SCALP = 1,
   CAT_INTRA = 2,
   CAT_NONE  = 3
};

//--- Get category for a timeframe index
ENUM_TF_CATEGORY GetCategory(int idx)
{
   if(idx >= ENTRY_MIN_IDX && idx <= ENTRY_MAX_IDX) return CAT_ENTRY;
   if(idx >= SCALP_MIN_IDX && idx <= SCALP_MAX_IDX) return CAT_SCALP;
   if(idx >= INTRA_MIN_IDX && idx <= INTRA_MAX_IDX) return CAT_INTRA;
   return CAT_NONE;
}

//--- Get category string
string GetCategoryStr(ENUM_TF_CATEGORY cat)
{
   switch(cat)
   {
      case CAT_ENTRY: return "ENTRY";
      case CAT_SCALP: return "SCALP";
      case CAT_INTRA: return "INTRA";
      default: return "NONE";
   }
}

//--- Format TF label
string FormatTFLabel(int minutes)
{
   if(minutes >= 60 && minutes % 60 == 0)
      return IntegerToString(minutes / 60) + "H";
   return IntegerToString(minutes) + "m";
}

//--- Box state enumeration
enum ENUM_BOX_STATE
{
   STATE_FORMING = 0,
   STATE_ESTABLISHED = 1,
   STATE_EST_RETEST = 2,
   STATE_RESPECTED = 3,
   STATE_FORMING_FRESH = 4
};

//--- Tracked box structure
struct TrackedBox
{
   string   direction;      // "bear" or "bull"
   ENUM_BOX_STATE state;
   double   top_val;
   double   bottom_val;
   double   original_top;
   double   original_bottom;
   datetime creation_time;
   datetime protection_end_time;
   string   pattern_text;
   string   base_pattern;
   string   timeframe;
   int      tf_minutes;
   bool     has_est_retest;
   string   retest_type;
   bool     protection_active;
   int      hcs_count;
   bool     has_been_retested;
   bool     is_intra;
   double   est_wick_high;
   double   est_wick_low;
   bool     completed_est_retest;
   bool     is_em_forming;
   bool     just_established;
   string   obj_name;       // Object name for visual box
   
   void Init()
   {
      direction = "";
      state = STATE_FORMING;
      top_val = 0;
      bottom_val = 0;
      original_top = 0;
      original_bottom = 0;
      creation_time = 0;
      protection_end_time = 0;
      pattern_text = "";
      base_pattern = "";
      timeframe = "";
      tf_minutes = 0;
      has_est_retest = false;
      retest_type = "FRESH";
      protection_active = true;
      hcs_count = 0;
      has_been_retested = false;
      is_intra = false;
      est_wick_high = 0;
      est_wick_low = 0;
      completed_est_retest = false;
      is_em_forming = false;
      just_established = false;
      obj_name = "";
   }
};

//--- LAOL line structure
struct LaolLineData
{
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
   string   obj_line_name;
   string   obj_label_name;
   
   void Init()
   {
      level = 0;
      tf_labels = "";
      creation_bar = 0;
      is_bear = false;
      is_broken = false;
      break_bar = 0;
      tf_count = 1;
      has_entry = false;
      has_scalp = false;
      has_intra = false;
      obj_line_name = "";
      obj_label_name = "";
   }
};

//--- Last Valid Info structure
struct LastValidInfo
{
   string   pattern_text;
   string   original_text;
   double   level;
   datetime est_time;
   string   direction;
   bool     is_broken;
   
   void Init()
   {
      pattern_text = "None";
      original_text = "None";
      level = 0;
      est_time = 0;
      direction = "";
      is_broken = false;
   }
};

//--- Sequence state structure
struct SeqState
{
   int      step;
   double   level;
   double   body;
   datetime start_time;
   
   void Init()
   {
      step = 0;
      level = 0;
      body = 0;
      start_time = 0;
   }
};

//--- HCS Box structure
struct HCSBoxData
{
   double   top_val;
   double   bottom_val;
   int      creation_bar;
   string   tf_label;
   string   direction;
   bool     is_broken;
   string   obj_name;
   
   void Init()
   {
      top_val = 0;
      bottom_val = 0;
      creation_bar = 0;
      tf_label = "";
      direction = "";
      is_broken = false;
      obj_name = "";
   }
};

//--- RR Box Set structure
struct RRBoxSet
{
   string   direction;
   double   sl_level;
   int      creation_bar;
   string   obj_sl_name;
   string   obj_tp_name;
   string   obj_pip_name;
   
   void Init()
   {
      direction = "";
      sl_level = 0;
      creation_bar = 0;
      obj_sl_name = "";
      obj_tp_name = "";
      obj_pip_name = "";
   }
};

//--- Global arrays for pattern detection
bool arr_fu_bear[TF_COUNT];
bool arr_fu_bull[TF_COUNT];
bool arr_sn_bear[TF_COUNT];
bool arr_sn_bull[TF_COUNT];
bool arr_first_bear[TF_COUNT];
bool arr_first_bull[TF_COUNT];
bool arr_second_bear[TF_COUNT];
bool arr_second_bull[TF_COUNT];
bool arr_third_bear[TF_COUNT];
bool arr_third_bull[TF_COUNT];
bool arr_laol_bear[TF_COUNT];
bool arr_laol_bull[TF_COUNT];
bool arr_laol_first_bear[TF_COUNT];
bool arr_laol_first_bull[TF_COUNT];
bool arr_laol_candle_bear[TF_COUNT];
bool arr_laol_candle_bull[TF_COUNT];

double arr_tf_h[TF_COUNT];
double arr_tf_l[TF_COUNT];
double arr_tf_bt[TF_COUNT];  // body top
double arr_tf_bb[TF_COUNT];  // body bottom
datetime arr_tf_t[TF_COUNT];
bool arr_tf_conf[TF_COUNT];

//--- Sequence states
SeqState arr_bear_seq[TF_COUNT];
SeqState arr_bull_seq[TF_COUNT];

//--- HCS arrays
bool arr_bear_hcs[TF_COUNT];
bool arr_bull_hcs[TF_COUNT];
bool arr_bear_hcs_forming[TF_COUNT];
bool arr_bull_hcs_forming[TF_COUNT];
datetime arr_last_bear_hcs_time[TF_COUNT];
datetime arr_last_bull_hcs_time[TF_COUNT];
bool arr_bear_hcs_broken[TF_COUNT];
bool arr_bull_hcs_broken[TF_COUNT];
bool arr_bear_hcs_retesting[TF_COUNT];
bool arr_bull_hcs_retesting[TF_COUNT];

//--- Third candle detection arrays
int arr_bear_third_step[TF_COUNT];
double arr_bear_third_ref_h[TF_COUNT];
double arr_bear_third_ref_l[TF_COUNT];
datetime arr_bear_third_ref_time[TF_COUNT];
int arr_bull_third_step[TF_COUNT];
double arr_bull_third_ref_h[TF_COUNT];
double arr_bull_third_ref_l[TF_COUNT];
datetime arr_bull_third_ref_time[TF_COUNT];

//--- LAOL step detection arrays
int arr_bear_laol_step[TF_COUNT];
double arr_bear_laol_ref_h[TF_COUNT];
double arr_bear_laol_ref_l[TF_COUNT];
datetime arr_bear_laol_ref_time[TF_COUNT];
int arr_bull_laol_step[TF_COUNT];
double arr_bull_laol_ref_h[TF_COUNT];
double arr_bull_laol_ref_l[TF_COUNT];
datetime arr_bull_laol_ref_time[TF_COUNT];

//--- Retesting arrays
bool arr_bear_retesting[TF_COUNT];
bool arr_bull_retesting[TF_COUNT];
bool arr_bear_est_retest[TF_COUNT];
bool arr_bull_est_retest[TF_COUNT];
bool arr_bear_est_retest_VALID[TF_COUNT];
bool arr_bull_est_retest_VALID[TF_COUNT];
string arr_bear_retest_pattern[TF_COUNT];
string arr_bull_retest_pattern[TF_COUNT];
double arr_bear_retest_level[TF_COUNT];
double arr_bull_retest_level[TF_COUNT];

//--- Dynamic arrays for tracked boxes (max per TF)
#define MAX_BOXES_PER_TF 50
TrackedBox tf_boxes[TF_COUNT][MAX_BOXES_PER_TF];
int tf_boxes_count[TF_COUNT];

//--- LAOL lines arrays
#define MAX_LAOL_LINES 100
LaolLineData bear_laol_lines[MAX_LAOL_LINES];
int bear_laol_count = 0;
LaolLineData bull_laol_lines[MAX_LAOL_LINES];
int bull_laol_count = 0;
LaolLineData bear_scalp_laol_lines[MAX_LAOL_LINES];
int bear_scalp_laol_count = 0;
LaolLineData bull_scalp_laol_lines[MAX_LAOL_LINES];
int bull_scalp_laol_count = 0;
LaolLineData bear_intra_laol_lines[MAX_LAOL_LINES];
int bear_intra_laol_count = 0;
LaolLineData bull_intra_laol_lines[MAX_LAOL_LINES];
int bull_intra_laol_count = 0;

//--- HCS Boxes
#define MAX_HCS_BOXES 50
HCSBoxData hcs_boxes_bear[MAX_HCS_BOXES];
int hcs_boxes_bear_count = 0;
HCSBoxData hcs_boxes_bull[MAX_HCS_BOXES];
int hcs_boxes_bull_count = 0;

//--- RR Boxes
#define MAX_RR_BOXES 50
RRBoxSet rr_boxes_bear[MAX_RR_BOXES];
int rr_boxes_bear_count = 0;
RRBoxSet rr_boxes_bull[MAX_RR_BOXES];
int rr_boxes_bull_count = 0;

//--- Last Valid info
LastValidInfo entry_bear_lv;
LastValidInfo entry_bull_lv;
LastValidInfo scalp_bear_lv;
LastValidInfo scalp_bull_lv;
LastValidInfo intra_bear_lv;
LastValidInfo intra_bull_lv;

//--- LAOL break tracking
datetime last_bear_laol_break_time = 0;
datetime last_bull_laol_break_time = 0;
string last_bear_laol_tf = "";
string last_bull_laol_tf = "";
datetime last_bear_intra_laol_break_time = 0;
datetime last_bull_intra_laol_break_time = 0;
string last_bear_intra_laol_tf = "";
string last_bull_intra_laol_tf = "";
datetime last_bear_scalp_laol_break_time = 0;
datetime last_bull_scalp_laol_break_time = 0;
string last_bear_scalp_laol_tf = "";
string last_bull_scalp_laol_tf = "";

//--- Final entry tracking
int final_entry_bear_setup_bar = -1;
int final_entry_bull_setup_bar = -1;
string final_entry_bear_pattern = "";
string final_entry_bull_pattern = "";

//--- Intra negation tracking
bool intra_bear_negating = false;
bool intra_bull_negating = false;
string intra_bear_negating_pattern = "";
string intra_bull_negating_pattern = "";

//--- Forming RR tracking
string bear_forming_rr_obj_sl = "";
string bear_forming_rr_obj_tp = "";
string bear_forming_rr_obj_pip = "";
int bear_forming_rr_bar = -1;
string bear_forming_type = "";
string bear_forming_type_prev = "";

string bull_forming_rr_obj_sl = "";
string bull_forming_rr_obj_tp = "";
string bull_forming_rr_obj_pip = "";
int bull_forming_rr_bar = -1;
string bull_forming_type = "";
string bull_forming_type_prev = "";

//--- Pip value
double pip_value = 0;

//--- Object counter for unique names
int g_obj_counter = 0;

//--- Bars processed tracking
int g_prev_calculated = 0;

//+------------------------------------------------------------------+
//| Helper: Generate unique object name                               |
//+------------------------------------------------------------------+
string GenObjName(string prefix)
{
   g_obj_counter++;
   return "STX_" + prefix + "_" + IntegerToString(g_obj_counter);
}

//+------------------------------------------------------------------+
//| Helper: Check if pattern is FU-only (no EM modifiers)            |
//+------------------------------------------------------------------+
bool IsFUPattern(string pattern)
{
   if(pattern == "") return false;
   bool has_fu = (StringFind(pattern, "FU") >= 0);
   bool has_sn = (StringFind(pattern, "SN") >= 0);
   bool has_em = (StringFind(pattern, "HCS") >= 0) || 
                 (StringFind(pattern, "Third") >= 0) || 
                 (StringFind(pattern, "First") >= 0) || 
                 (StringFind(pattern, "LAOL") >= 0) || 
                 (StringFind(pattern, "TBE") >= 0);
   return (has_fu || has_sn) && !has_em;
}

//+------------------------------------------------------------------+
//| Helper: Check if pattern is EM (has modifiers)                   |
//+------------------------------------------------------------------+
bool IsEMPattern(string pattern)
{
   if(pattern == "") return false;
   return (StringFind(pattern, "HCS") >= 0) || 
          (StringFind(pattern, "Third") >= 0) || 
          (StringFind(pattern, "First") >= 0) || 
          (StringFind(pattern, "LAOL") >= 0) || 
          (StringFind(pattern, "TBE") >= 0) || 
          (StringFind(pattern, "[EM]") >= 0);
}

//+------------------------------------------------------------------+
//| Helper: Check if candle has both wicks                           |
//+------------------------------------------------------------------+
bool HasBothWicks(double o, double h, double l, double c)
{
   return (MathMax(o, c) < h) && (MathMin(o, c) > l);
}

//+------------------------------------------------------------------+
//| Helper: Check if bar is inside bar                               |
//+------------------------------------------------------------------+
bool IsInsideBar(double h, double l, double h1, double l1)
{
   return (h < h1) && (l > l1);
}

//+------------------------------------------------------------------+
//| Helper: Build pattern string                                     |
//+------------------------------------------------------------------+
string BuildPatternStr(bool is_bear, bool third, bool first, bool laol, 
                       bool sn, bool sn_dbl, bool fu, bool tbe, 
                       bool hcs, bool hcs_forming)
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
//| Helper: Time ago string                                          |
//+------------------------------------------------------------------+
string TimeAgo(datetime past_time)
{
   if(past_time == 0) return "";
   
   long elapsed_sec = (long)(TimeCurrent() - past_time);
   int elapsed_min = (int)(elapsed_sec / 60);
   
   if(elapsed_min < 1)
      return " (<1m ago)";
   else if(elapsed_min < 60)
      return " (" + IntegerToString(elapsed_min) + "m ago)";
   else if(elapsed_min < 1440)
   {
      int hours = elapsed_min / 60;
      int mins = elapsed_min % 60;
      return " (" + IntegerToString(hours) + "h" + 
             (mins > 0 ? IntegerToString(mins) + "m" : "") + " ago)";
   }
   else
   {
      int days = elapsed_min / 1440;
      return " (" + IntegerToString(days) + "d ago)";
   }
}

//+------------------------------------------------------------------+
//| Helper: Check LV break                                           |
//+------------------------------------------------------------------+
void CheckBreak(LastValidInfo &lv, double h, double l)
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
//| Helper: Resolve last valid between bear and bull                 |
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
//| Get MTF data for a timeframe index                               |
//+------------------------------------------------------------------+
struct TFBarData
{
   double o2, h2, l2, c2;  // bar[2]
   double o1, h1, l1, c1;  // bar[1]
   double o0, h0, l0, c0;  // bar[0]
   datetime time0;
   bool confirmed;
};

bool GetTFData(int tf_idx, TFBarData &data)
{
   int minutes = TF_MINUTES[tf_idx];
   ENUM_TIMEFRAMES tf = GetTimeframe(minutes);
   
   double open_arr[], high_arr[], low_arr[], close_arr[];
   datetime time_arr[];
   
   // Copy 3 bars of data (indices 0,1,2 where 0 is current)
   if(CopyOpen(_Symbol, tf, 0, 3, open_arr) < 3) return false;
   if(CopyHigh(_Symbol, tf, 0, 3, high_arr) < 3) return false;
   if(CopyLow(_Symbol, tf, 0, 3, low_arr) < 3) return false;
   if(CopyClose(_Symbol, tf, 0, 3, close_arr) < 3) return false;
   if(CopyTime(_Symbol, tf, 0, 3, time_arr) < 3) return false;
   
   // MT5 arrays are ordered oldest to newest after Copy
   // So index 0 = oldest (bar[2]), index 1 = bar[1], index 2 = bar[0] current
   data.o2 = open_arr[0];  data.h2 = high_arr[0];  data.l2 = low_arr[0];  data.c2 = close_arr[0];
   data.o1 = open_arr[1];  data.h1 = high_arr[1];  data.l1 = low_arr[1];  data.c1 = close_arr[1];
   data.o0 = open_arr[2];  data.h0 = high_arr[2];  data.l0 = low_arr[2];  data.c0 = close_arr[2];
   data.time0 = time_arr[2];
   
   // A bar is "confirmed" if the current chart time has moved past the TF bar's close
   // For the latest completed bar, we use bar[1] as confirmed and bar[0] as forming
   // Replicating Pine's barstate.isconfirmed: the TF bar is confirmed when
   // current chart time >= TF bar open time + period duration
   datetime bar_end = time_arr[2] + minutes * 60;
   data.confirmed = (TimeCurrent() >= bar_end);
   
   // Actually for MTF analysis we want the LAST COMPLETED bar's data
   // Pine's request.security with [2],[1],[0] gives confirmed bars
   // Let's shift: use bar[1] as "current" (last completed) and bar[2] as previous
   // But only if not confirmed yet for bar[0]
   // Simplified approach: always use bar[1] as the "signal" bar (confirmed)
   // and bar[0] as forming
   
   // Re-read using shift 1 as the "current confirmed" bar
   if(CopyOpen(_Symbol, tf, 1, 3, open_arr) < 3) return false;
   if(CopyHigh(_Symbol, tf, 1, 3, high_arr) < 3) return false;
   if(CopyLow(_Symbol, tf, 1, 3, low_arr) < 3) return false;
   if(CopyClose(_Symbol, tf, 1, 3, close_arr) < 3) return false;
   if(CopyTime(_Symbol, tf, 1, 3, time_arr) < 3) return false;
   
   data.o2 = open_arr[0];  data.h2 = high_arr[0];  data.l2 = low_arr[0];  data.c2 = close_arr[0];
   data.o1 = open_arr[1];  data.h1 = high_arr[1];  data.l1 = low_arr[1];  data.c1 = close_arr[1];
   data.o0 = open_arr[2];  data.h0 = high_arr[2];  data.l0 = low_arr[2];  data.c0 = close_arr[2];
   data.time0 = time_arr[2];
   
   // Check if this TF bar has changed since last calc (confirmed)
   // For simplicity, bar is confirmed when we can read it as a closed bar
   data.confirmed = true; // bars shifted by 1 are always confirmed
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate patterns for a given TF index                          |
//+------------------------------------------------------------------+
void CalculatePatterns(int idx, TFBarData &data)
{
   double p_o2 = data.o2, p_h2 = data.h2, p_l2 = data.l2, p_c2 = data.c2;
   double p_o1 = data.o1, p_h1 = data.h1, p_l1 = data.l1, p_c1 = data.c1;
   double p_o  = data.o0, p_h  = data.h0, p_l  = data.l0, p_c  = data.c0;
   datetime p_t = data.time0;
   bool p_conf = data.confirmed;
   
   bool valid_data   = (p_h > 0 && p_l > 0 && p_c > 0 && p_o > 0);
   bool valid_data_1 = (p_h1 > 0 && p_l1 > 0 && p_c1 > 0 && p_o1 > 0);
   bool valid_data_2 = (p_h2 > 0 && p_l2 > 0 && p_c2 > 0 && p_o2 > 0);
   
   bool both_sides   = valid_data ? HasBothWicks(p_o, p_h, p_l, p_c) : false;
   bool both_sides_1 = valid_data_1 ? HasBothWicks(p_o1, p_h1, p_l1, p_c1) : false;
   
   double body_top    = valid_data ? MathMax(p_o, p_c) : 0;
   double body_bottom = valid_data ? MathMin(p_o, p_c) : 0;
   
   bool is_ib = (valid_data && valid_data_1) ? IsInsideBar(p_h, p_l, p_h1, p_l1) : false;
   
   // X3 detection
   bool bear_x3 = valid_data && valid_data_1 && p_h > p_h1 && p_l < p_l1 && both_sides && p_c < p_o;
   bool bull_x3 = valid_data && valid_data_1 && p_h > p_h1 && p_l < p_l1 && both_sides && p_c > p_o;
   bool is_x3 = bear_x3 || bull_x3;
   
   bool bear_x3_1 = (valid_data_1 && valid_data_2) ? (p_h1 > p_h2 && p_l1 < p_l2 && both_sides_1 && p_c1 < p_o1) : false;
   bool bull_x3_1 = (valid_data_1 && valid_data_2) ? (p_h1 > p_h2 && p_l1 < p_l2 && both_sides_1 && p_c1 > p_o1) : false;
   bool is_x3_1 = bear_x3_1 || bull_x3_1;
   
   // SN detection
   bool sn_bull = p_h > p_h1 && p_l < p_l1 && MathMax(p_o, p_c) < p_h1 && MathMin(p_o, p_c) > p_l1 && p_o < p_c;
   bool sn_bear = p_h > p_h1 && p_l < p_l1 && MathMin(p_o, p_c) > p_l1 && MathMax(p_o, p_c) < p_h1 && p_o > p_c;
   bool sn_together = (sn_bull || sn_bear) && !is_x3;
   
   bool sn_bull_1 = (valid_data_1 && valid_data_2) ? (p_h1 > p_h2 && p_l1 < p_l2 && p_c1 > p_o1 && MathMax(p_o1, p_c1) < p_h2) : false;
   bool sn_bear_1 = (valid_data_1 && valid_data_2) ? (p_h1 > p_h2 && p_l1 < p_l2 && p_c1 < p_o1 && MathMin(p_o1, p_c1) > p_l2) : false;
   bool sn_together_1 = (sn_bull_1 || sn_bear_1) && !is_x3_1;
   
   // LAOL First detection
   bool bull_laol_first = valid_data && valid_data_1 && valid_data_2 && 
                          p_l1 == MathMin(p_o1, p_c1) && p_h1 < p_h2 && p_h < p_h1 && p_l < p_l1;
   bool bear_laol_first = valid_data && valid_data_1 && valid_data_2 && 
                          p_h1 == MathMax(p_o1, p_c1) && p_l1 > p_l2 && p_l > p_l1 && p_h > p_h1;
   
   // X3 First (EM) detection
   bool bear_first_em = (bull_x3_1 || sn_together_1) && p_h > p_h1 && p_l > p_l1;
   bool bull_first_em = (bear_x3_1 || sn_together_1) && p_l < p_l1 && p_h < p_h1;
   
   // LAOL candle (inside bar)
   bool bear_laol_candle = is_ib;
   bool bull_laol_candle = is_ib;
   
   // FU detection
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
//| Update sequence state (TBE detection)                            |
//+------------------------------------------------------------------+
bool UpdateSeq(SeqState &seq, bool is_fu, bool is_x3, bool counter_fu, 
               bool counter_x3, double level, double body, int tf_minutes,
               bool confirmed, bool is_bear, double p_h, double p_l)
{
   if(!confirmed) return false;
   
   int tf_seconds = tf_minutes * 60;
   int candles_since = 0;
   if(seq.start_time > 0)
      candles_since = (int)((TimeCurrent() - seq.start_time) / tf_seconds);
   
   if(seq.step > 0 && seq.step < 5 && candles_since > 5)
   {
      seq.step = 0;
      seq.level = 0;
      seq.body = 0;
      seq.start_time = 0;
   }
   
   bool is_valid = false;
   
   if(seq.step == 5)
   {
      seq.step = 0;
      seq.level = 0;
      seq.body = 0;
      seq.start_time = 0;
   }
   else if(seq.step == 4)
   {
      bool broke_level = is_bear ? (p_h > seq.level) : (p_l < seq.level);
      if(broke_level)
      {
         seq.step = 0; seq.level = 0; seq.body = 0; seq.start_time = 0;
      }
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
      {
         seq.step = 0; seq.level = 0; seq.body = 0; seq.start_time = 0;
      }
      else if(in_zone)
         seq.step = 4;
   }
   else if(seq.step == 2)
   {
      bool broke_level = is_bear ? (p_h > seq.level) : (p_l < seq.level);
      if(broke_level)
      {
         seq.step = 0; seq.level = 0; seq.body = 0; seq.start_time = 0;
      }
      else if(counter_fu || counter_x3)
         seq.step = 3;
   }
   else if(seq.step == 1)
   {
      bool broke_level = is_bear ? (p_h > seq.level) : (p_l < seq.level);
      bool in_zone = is_bear ? (p_h >= seq.body && p_h <= seq.level) : (p_l <= seq.body && p_l >= seq.level);
      if(broke_level)
      {
         seq.step = 0; seq.level = 0; seq.body = 0; seq.start_time = 0;
      }
      else if(in_zone)
         seq.step = 2;
      else
      {
         seq.step = 0; seq.level = 0; seq.body = 0; seq.start_time = 0;
      }
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
//| Add or merge LAOL line                                           |
//+------------------------------------------------------------------+
void AddOrMergeLaolLine(LaolLineData &lines[], int &count, double level, 
                        string tf_label, bool is_bear, string category)
{
   double tolerance = _Point * 20; // syminfo.mintick * 2
   bool merged = false;
   bool found_broken = false;
   
   for(int i = 0; i < count; i++)
   {
      if(MathAbs(lines[i].level - level) < tolerance)
      {
         if(lines[i].is_broken)
         {
            found_broken = true;
            break;
         }
         if(StringFind(lines[i].tf_labels, tf_label) < 0)
         {
            lines[i].tf_labels += "," + tf_label;
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
      lines[count].Init();
      lines[count].level = level;
      lines[count].tf_labels = tf_label;
      lines[count].creation_bar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR); // approximate bar_index
      lines[count].is_bear = is_bear;
      lines[count].tf_count = 1;
      lines[count].has_entry = (category == "ENTRY");
      lines[count].has_scalp = (category == "SCALP");
      lines[count].has_intra = (category == "INTRA");
      count++;
   }
}

//+------------------------------------------------------------------+
//| Update LAOL lines - check breaks                                 |
//+------------------------------------------------------------------+
void UpdateLaolLines(LaolLineData &lines[], int &count, bool is_bear, double current_price,
                     datetime &break_time, string &break_tf,
                     datetime &intra_break_time, string &intra_break_tf,
                     datetime &scalp_break_time, string &scalp_break_tf)
{
   break_time = 0;
   break_tf = "";
   intra_break_time = 0;
   intra_break_tf = "";
   scalp_break_time = 0;
   scalp_break_tf = "";
   
   int current_bar = Bars(_Symbol, PERIOD_CURRENT) - 1;
   
   for(int idx = count - 1; idx >= 0; idx--)
   {
      bool crossed = is_bear ? (current_price > lines[idx].level) : (current_price < lines[idx].level);
      
      if(crossed && !lines[idx].is_broken)
      {
         lines[idx].is_broken = true;
         lines[idx].break_bar = current_bar;
         
         if(lines[idx].has_intra)
         {
            intra_break_time = TimeCurrent();
            intra_break_tf = lines[idx].tf_labels;
         }
         else if(lines[idx].has_scalp)
         {
            scalp_break_time = TimeCurrent();
            scalp_break_tf = lines[idx].tf_labels;
         }
         else
         {
            break_time = TimeCurrent();
            break_tf = lines[idx].tf_labels;
         }
      }
      
      if(lines[idx].is_broken && current_bar >= lines[idx].break_bar + InpLaolDeleteDelay)
      {
         // Remove by shifting
         for(int j = idx; j < count - 1; j++)
            lines[j] = lines[j+1];
         count--;
      }
   }
}

//+------------------------------------------------------------------+
//| Get broken LAOL (recent)                                         |
//+------------------------------------------------------------------+
bool GetBrokenLaolRecent(LaolLineData &lines[], int count, bool require_multi, 
                         double &result_level, int lookback = 5)
{
   result_level = 0;
   int current_bar = Bars(_Symbol, PERIOD_CURRENT) - 1;
   
   for(int i = 0; i < count; i++)
   {
      if(lines[i].is_broken && (current_bar - lines[i].break_bar) <= lookback)
      {
         if(!require_multi || lines[i].tf_count >= 2)
         {
            result_level = lines[i].level;
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Merge cross category LAOL                                        |
//+------------------------------------------------------------------+
bool MergeCrossCategory(LaolLineData &entry_lines[], int entry_count,
                        LaolLineData &scalp_lines[], int scalp_count,
                        LaolLineData &intra_lines[], int intra_count,
                        double level, string tf_label, bool is_bear)
{
   double tolerance = _Point * 20;
   
   for(int i = 0; i < intra_count; i++)
   {
      if(MathAbs(intra_lines[i].level - level) < tolerance && !intra_lines[i].is_broken)
      {
         if(StringFind(intra_lines[i].tf_labels, tf_label) < 0)
         {
            intra_lines[i].tf_labels += "," + tf_label;
            intra_lines[i].tf_count++;
         }
         return true;
      }
   }
   for(int i = 0; i < scalp_count; i++)
   {
      if(MathAbs(scalp_lines[i].level - level) < tolerance && !scalp_lines[i].is_broken)
      {
         if(StringFind(scalp_lines[i].tf_labels, tf_label) < 0)
         {
            scalp_lines[i].tf_labels += "," + tf_label;
            scalp_lines[i].tf_count++;
         }
         return true;
      }
   }
   for(int i = 0; i < entry_count; i++)
   {
      if(MathAbs(entry_lines[i].level - level) < tolerance && !entry_lines[i].is_broken)
      {
         if(StringFind(entry_lines[i].tf_labels, tf_label) < 0)
         {
            entry_lines[i].tf_labels += "," + tf_label;
            entry_lines[i].tf_count++;
         }
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Manage tracked boxes for a timeframe                             |
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
   
   bool is_entry_tf = (tf_minutes >= 1 && tf_minutes <= 5);
   int protection_candles = is_entry_tf ? 3 : 1;
   
   for(int idx = tf_boxes_count[tf_idx] - 1; idx >= 0; idx--)
   {
      
      if(tf_boxes[tf_idx][idx].direction == "bear")
      {
         // Check invalidation
         if(p_h > 0 && p_h > tf_boxes[tf_idx][idx].original_top)
         {
            // Remove box - shift array
            if(tf_boxes[tf_idx][idx].obj_name != "") ObjectDelete(0, tf_boxes[tf_idx][idx].obj_name);
            for(int j = idx; j < tf_boxes_count[tf_idx] - 1; j++)
               tf_boxes[tf_idx][j] = tf_boxes[tf_idx][j+1];
            tf_boxes_count[tf_idx]--;
            continue;
         }
         
         if(tf_boxes[tf_idx][idx].state == STATE_FORMING)
         {
            if(p_conf)
            {
               tf_boxes[tf_idx][idx].state = STATE_ESTABLISHED;
               tf_boxes[tf_idx][idx].just_established = true;
               tf_boxes[tf_idx][idx].protection_end_time = p_t + tf_minutes * 60 * protection_candles;
               tf_boxes[tf_idx][idx].protection_active = true;
               tf_boxes[tf_idx][idx].est_wick_high = p_h;
               tf_boxes[tf_idx][idx].est_wick_low = p_l;
            }
         }
         else if(tf_boxes[tf_idx][idx].state == STATE_ESTABLISHED)
         {
            bool wick_zone_touched = (p_h > 0 && p_h >= tf_boxes[tf_idx][idx].bottom_val && p_h < tf_boxes[tf_idx][idx].original_top);
            if(tf_boxes[tf_idx][idx].protection_active)
            {
               if(wick_zone_touched)
               {
                  bool wick_in_range = (tf_boxes[tf_idx][idx].est_wick_high > 0 && tf_boxes[tf_idx][idx].est_wick_low > 0 && 
                                       p_h >= tf_boxes[tf_idx][idx].est_wick_low && p_h <= tf_boxes[tf_idx][idx].est_wick_high);
                  if(wick_in_range)
                  {
                     tf_boxes[tf_idx][idx].state = STATE_EST_RETEST;
                     tf_boxes[tf_idx][idx].has_est_retest = true;
                     tf_boxes[tf_idx][idx].has_been_retested = true;
                     tf_boxes[tf_idx][idx].retest_type = "EST+RETEST";
                     bear_est = true;
                     bear_pat = tf_boxes[tf_idx][idx].pattern_text + " [EST+RET]";
                     bear_lvl = tf_boxes[tf_idx][idx].original_top;
                  }
                  else
                  {
                     tf_boxes[tf_idx][idx].state = STATE_FORMING_FRESH;
                     tf_boxes[tf_idx][idx].has_been_retested = true;
                     bear_ret = true;
                     bear_pat = tf_boxes[tf_idx][idx].pattern_text + " [FRESH FORMING]";
                     bear_lvl = tf_boxes[tf_idx][idx].original_top;
                  }
               }
               if(p_conf && p_t >= tf_boxes[tf_idx][idx].protection_end_time)
               {
                  tf_boxes[tf_idx][idx].protection_active = false;
                  if(tf_boxes[tf_idx][idx].state == STATE_ESTABLISHED)
                  {
                     tf_boxes[tf_idx][idx].retest_type = "FRESH";
                     tf_boxes[tf_idx][idx].completed_est_retest = true;
                  }
               }
            }
            else
            {
               if(wick_zone_touched)
               {
                  tf_boxes[tf_idx][idx].state = STATE_RESPECTED;
                  tf_boxes[tf_idx][idx].has_been_retested = true;
                  bear_ret = true;
                  bear_pat = tf_boxes[tf_idx][idx].pattern_text + " [FRESH]";
                  bear_lvl = tf_boxes[tf_idx][idx].original_top;
                  if(p_h > tf_boxes[tf_idx][idx].bottom_val && p_h < tf_boxes[tf_idx][idx].top_val)
                     tf_boxes[tf_idx][idx].bottom_val = p_h;
               }
            }
         }
         else if(tf_boxes[tf_idx][idx].state == STATE_FORMING_FRESH)
         {
            bool wick_zone_touched = (p_h > 0 && p_h >= tf_boxes[tf_idx][idx].bottom_val && p_h < tf_boxes[tf_idx][idx].original_top);
            if(wick_zone_touched)
            {
               bear_ret = true;
               bear_pat = tf_boxes[tf_idx][idx].pattern_text + " [FRESH FORMING]";
               bear_lvl = tf_boxes[tf_idx][idx].original_top;
            }
            if(p_conf && p_t >= tf_boxes[tf_idx][idx].protection_end_time)
            {
               tf_boxes[tf_idx][idx].state = STATE_RESPECTED;
               tf_boxes[tf_idx][idx].protection_active = false;
               tf_boxes[tf_idx][idx].retest_type = "FRESH";
               tf_boxes[tf_idx][idx].completed_est_retest = true;
            }
         }
         else if(tf_boxes[tf_idx][idx].state == STATE_EST_RETEST)
         {
            bool wick_zone_touched = (p_h > 0 && p_h >= tf_boxes[tf_idx][idx].bottom_val && p_h < tf_boxes[tf_idx][idx].original_top);
            bear_est = true;
            bear_pat = tf_boxes[tf_idx][idx].pattern_text + " [EST+RET]";
            bear_lvl = tf_boxes[tf_idx][idx].original_top;
            if(wick_zone_touched) bear_ret = true;
            if(p_conf && p_t >= tf_boxes[tf_idx][idx].protection_end_time)
            {
               bear_est_valid = true;
               tf_boxes[tf_idx][idx].state = STATE_RESPECTED;
               tf_boxes[tf_idx][idx].protection_active = false;
               tf_boxes[tf_idx][idx].retest_type = "FRESH";
               tf_boxes[tf_idx][idx].completed_est_retest = true;
            }
         }
         else if(tf_boxes[tf_idx][idx].state == STATE_RESPECTED)
         {
            bool is_touching = (p_h > 0 && p_h >= tf_boxes[tf_idx][idx].bottom_val && p_l <= tf_boxes[tf_idx][idx].top_val);
            if(is_touching)
            {
               bear_ret = true;
               bear_pat = tf_boxes[tf_idx][idx].pattern_text + " [" + tf_boxes[tf_idx][idx].retest_type + "]";
               bear_lvl = tf_boxes[tf_idx][idx].original_top;
               if(p_h > tf_boxes[tf_idx][idx].bottom_val && p_h < tf_boxes[tf_idx][idx].top_val)
                  tf_boxes[tf_idx][idx].bottom_val = p_h;
            }
         }
      }
      else if(tf_boxes[tf_idx][idx].direction == "bull")
      {
         // Check invalidation
         if(p_l > 0 && p_l < tf_boxes[tf_idx][idx].original_bottom)
         {
            if(tf_boxes[tf_idx][idx].obj_name != "") ObjectDelete(0, tf_boxes[tf_idx][idx].obj_name);
            for(int j = idx; j < tf_boxes_count[tf_idx] - 1; j++)
               tf_boxes[tf_idx][j] = tf_boxes[tf_idx][j+1];
            tf_boxes_count[tf_idx]--;
            continue;
         }
         
         if(tf_boxes[tf_idx][idx].state == STATE_FORMING)
         {
            if(p_conf)
            {
               tf_boxes[tf_idx][idx].state = STATE_ESTABLISHED;
               tf_boxes[tf_idx][idx].just_established = true;
               tf_boxes[tf_idx][idx].protection_end_time = p_t + tf_minutes * 60 * protection_candles;
               tf_boxes[tf_idx][idx].protection_active = true;
               tf_boxes[tf_idx][idx].est_wick_high = p_h;
               tf_boxes[tf_idx][idx].est_wick_low = p_l;
            }
         }
         else if(tf_boxes[tf_idx][idx].state == STATE_ESTABLISHED)
         {
            bool wick_zone_touched = (p_l > 0 && p_l <= tf_boxes[tf_idx][idx].top_val && p_l > tf_boxes[tf_idx][idx].original_bottom);
            if(tf_boxes[tf_idx][idx].protection_active)
            {
               if(wick_zone_touched)
               {
                  bool wick_in_range = (tf_boxes[tf_idx][idx].est_wick_high > 0 && tf_boxes[tf_idx][idx].est_wick_low > 0 &&
                                       p_l >= tf_boxes[tf_idx][idx].est_wick_low && p_l <= tf_boxes[tf_idx][idx].est_wick_high);
                  if(wick_in_range)
                  {
                     tf_boxes[tf_idx][idx].state = STATE_EST_RETEST;
                     tf_boxes[tf_idx][idx].has_est_retest = true;
                     tf_boxes[tf_idx][idx].has_been_retested = true;
                     tf_boxes[tf_idx][idx].retest_type = "EST+RETEST";
                     bull_est = true;
                     bull_pat = tf_boxes[tf_idx][idx].pattern_text + " [EST+RET]";
                     bull_lvl = tf_boxes[tf_idx][idx].original_bottom;
                  }
                  else
                  {
                     tf_boxes[tf_idx][idx].state = STATE_FORMING_FRESH;
                     tf_boxes[tf_idx][idx].has_been_retested = true;
                     bull_ret = true;
                     bull_pat = tf_boxes[tf_idx][idx].pattern_text + " [FRESH FORMING]";
                     bull_lvl = tf_boxes[tf_idx][idx].original_bottom;
                  }
               }
               if(p_conf && p_t >= tf_boxes[tf_idx][idx].protection_end_time)
               {
                  tf_boxes[tf_idx][idx].protection_active = false;
                  if(tf_boxes[tf_idx][idx].state == STATE_ESTABLISHED)
                  {
                     tf_boxes[tf_idx][idx].retest_type = "FRESH";
                     tf_boxes[tf_idx][idx].completed_est_retest = true;
                  }
               }
            }
            else
            {
               if(wick_zone_touched)
               {
                  tf_boxes[tf_idx][idx].state = STATE_RESPECTED;
                  tf_boxes[tf_idx][idx].has_been_retested = true;
                  bull_ret = true;
                  bull_pat = tf_boxes[tf_idx][idx].pattern_text + " [FRESH]";
                  bull_lvl = tf_boxes[tf_idx][idx].original_bottom;
                  if(p_l < tf_boxes[tf_idx][idx].top_val && p_l > tf_boxes[tf_idx][idx].bottom_val)
                     tf_boxes[tf_idx][idx].top_val = p_l;
               }
            }
         }
         else if(tf_boxes[tf_idx][idx].state == STATE_FORMING_FRESH)
         {
            bool wick_zone_touched = (p_l > 0 && p_l <= tf_boxes[tf_idx][idx].top_val && p_l > tf_boxes[tf_idx][idx].original_bottom);
            if(wick_zone_touched)
            {
               bull_ret = true;
               bull_pat = tf_boxes[tf_idx][idx].pattern_text + " [FRESH FORMING]";
               bull_lvl = tf_boxes[tf_idx][idx].original_bottom;
            }
            if(p_conf && p_t >= tf_boxes[tf_idx][idx].protection_end_time)
            {
               tf_boxes[tf_idx][idx].state = STATE_RESPECTED;
               tf_boxes[tf_idx][idx].protection_active = false;
               tf_boxes[tf_idx][idx].retest_type = "FRESH";
               tf_boxes[tf_idx][idx].completed_est_retest = true;
            }
         }
         else if(tf_boxes[tf_idx][idx].state == STATE_EST_RETEST)
         {
            bool wick_zone_touched = (p_l > 0 && p_l <= tf_boxes[tf_idx][idx].top_val && p_l > tf_boxes[tf_idx][idx].original_bottom);
            bull_est = true;
            bull_pat = tf_boxes[tf_idx][idx].pattern_text + " [EST+RET]";
            bull_lvl = tf_boxes[tf_idx][idx].original_bottom;
            if(wick_zone_touched) bull_ret = true;
            if(p_conf && p_t >= tf_boxes[tf_idx][idx].protection_end_time)
            {
               bull_est_valid = true;
               tf_boxes[tf_idx][idx].state = STATE_RESPECTED;
               tf_boxes[tf_idx][idx].protection_active = false;
               tf_boxes[tf_idx][idx].retest_type = "FRESH";
               tf_boxes[tf_idx][idx].completed_est_retest = true;
            }
         }
         else if(tf_boxes[tf_idx][idx].state == STATE_RESPECTED)
         {
            bool is_touching = (p_l > 0 && p_l <= tf_boxes[tf_idx][idx].top_val && p_h >= tf_boxes[tf_idx][idx].bottom_val);
            if(is_touching)
            {
               bull_ret = true;
               bull_pat = tf_boxes[tf_idx][idx].pattern_text + " [" + tf_boxes[tf_idx][idx].retest_type + "]";
               bull_lvl = tf_boxes[tf_idx][idx].original_bottom;
               if(p_l < tf_boxes[tf_idx][idx].top_val && p_l > tf_boxes[tf_idx][idx].bottom_val)
                  tf_boxes[tf_idx][idx].top_val = p_l;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Create tracked box                                               |
//+------------------------------------------------------------------+
bool CreateBox(int tf_idx, string direction, double top_v, double bottom_v, 
               datetime creation_t, string pattern, int tf_minutes, bool is_intra)
{
   if(pattern == "" || top_v <= 0 || bottom_v <= 0 || creation_t == 0) return false;
   
   // Check if exists
   for(int i = 0; i < tf_boxes_count[tf_idx]; i++)
   {
      if(tf_boxes[tf_idx][i].creation_time == creation_t && 
         tf_boxes[tf_idx][i].direction == direction &&
         tf_boxes[tf_idx][i].tf_minutes == tf_minutes)
         return false;
   }
   
   if(tf_boxes_count[tf_idx] >= MAX_BOXES_PER_TF) return false;
   
   int idx = tf_boxes_count[tf_idx];
   tf_boxes[tf_idx][idx].Init();
   tf_boxes[tf_idx][idx].direction = direction;
   tf_boxes[tf_idx][idx].state = STATE_FORMING;
   tf_boxes[tf_idx][idx].top_val = top_v;
   tf_boxes[tf_idx][idx].bottom_val = bottom_v;
   tf_boxes[tf_idx][idx].original_top = top_v;
   tf_boxes[tf_idx][idx].original_bottom = bottom_v;
   tf_boxes[tf_idx][idx].creation_time = creation_t;
   tf_boxes[tf_idx][idx].pattern_text = pattern;
   tf_boxes[tf_idx][idx].base_pattern = pattern;
   tf_boxes[tf_idx][idx].timeframe = FormatTFLabel(tf_minutes);
   tf_boxes[tf_idx][idx].tf_minutes = tf_minutes;
   tf_boxes[tf_idx][idx].is_intra = is_intra;
   tf_boxes[tf_idx][idx].is_em_forming = IsEMPattern(pattern);
   
   // Create visual box object
   if(IsEMPattern(pattern))
   {
      string name = GenObjName("BOX");
      tf_boxes[tf_idx][idx].obj_name = name;
      
      int bar_start = iBarShift(_Symbol, PERIOD_CURRENT, creation_t);
      if(bar_start < 0) bar_start = 0;
      datetime time_start = iTime(_Symbol, PERIOD_CURRENT, bar_start);
      datetime time_end = time_start + PeriodSeconds(PERIOD_CURRENT) * 50;
      
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, time_start, top_v, time_end, bottom_v);
      
      ENUM_TF_CATEGORY cat = (tf_minutes <= 5) ? CAT_ENTRY : (tf_minutes <= 20) ? CAT_SCALP : CAT_INTRA;
      color box_clr, border_clr;
      if(cat == CAT_ENTRY) { box_clr = clrBlue; border_clr = clrBlue; }
      else if(cat == CAT_SCALP) { box_clr = clrGreen; border_clr = clrGreen; }
      else { box_clr = clrRed; border_clr = clrRed; }
      
      ObjectSetInteger(0, name, OBJPROP_COLOR, border_clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetString(0, name, OBJPROP_TEXT, pattern);
   }
   
   tf_boxes_count[tf_idx]++;
   return true;
}

//+------------------------------------------------------------------+
//| Manage HCS boxes                                                 |
//+------------------------------------------------------------------+
bool ManageHCSBoxes(HCSBoxData &boxes[], int &count, bool is_bear)
{
   bool any_retesting = false;
   double current_high = iHigh(_Symbol, PERIOD_CURRENT, 0);
   double current_low = iLow(_Symbol, PERIOD_CURRENT, 0);
   
   for(int idx = count - 1; idx >= 0; idx--)
   {
      if(is_bear)
      {
         if(!boxes[idx].is_broken && current_high > boxes[idx].top_val)
         {
            boxes[idx].is_broken = true;
            // Create visual HCS box
            string name = GenObjName("HCS");
            boxes[idx].obj_name = name;
            int bar_now = Bars(_Symbol, PERIOD_CURRENT) - 1;
            datetime t1 = iTime(_Symbol, PERIOD_CURRENT, bar_now - boxes[idx].creation_bar);
            datetime t2 = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 50;
            ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, boxes[idx].top_val, t2, boxes[idx].bottom_val);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrange);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, name, OBJPROP_FILL, true);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetString(0, name, OBJPROP_TEXT, "HCS BROKEN [" + boxes[idx].tf_label + "]");
         }
         if(boxes[idx].is_broken)
         {
            if(current_high >= boxes[idx].bottom_val && current_high <= boxes[idx].top_val)
               any_retesting = true;
            if(current_low < boxes[idx].bottom_val)
            {
               if(boxes[idx].obj_name != "") ObjectDelete(0, boxes[idx].obj_name);
               for(int j = idx; j < count - 1; j++) boxes[j] = boxes[j+1];
               count--;
               continue;
            }
         }
      }
      else
      {
         if(!boxes[idx].is_broken && current_low < boxes[idx].bottom_val)
         {
            boxes[idx].is_broken = true;
            string name = GenObjName("HCS");
            boxes[idx].obj_name = name;
            int bar_now = Bars(_Symbol, PERIOD_CURRENT) - 1;
            datetime t1 = iTime(_Symbol, PERIOD_CURRENT, bar_now - boxes[idx].creation_bar);
            datetime t2 = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 50;
            ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, boxes[idx].top_val, t2, boxes[idx].bottom_val);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrDodgerBlue);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, name, OBJPROP_FILL, true);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetString(0, name, OBJPROP_TEXT, "HCS BROKEN [" + boxes[idx].tf_label + "]");
         }
         if(boxes[idx].is_broken)
         {
            if(current_low >= boxes[idx].bottom_val && current_low <= boxes[idx].top_val)
               any_retesting = true;
            if(current_high > boxes[idx].top_val)
            {
               if(boxes[idx].obj_name != "") ObjectDelete(0, boxes[idx].obj_name);
               for(int j = idx; j < count - 1; j++) boxes[j] = boxes[j+1];
               count--;
               continue;
            }
         }
      }
   }
   return any_retesting;
}

//+------------------------------------------------------------------+
//| Find next extreme candle for SL extension                        |
//+------------------------------------------------------------------+
double FindNextExtremeCandle(string direction, double original_sl, int lookback = 500)
{
   double extreme_level = 0;
   if(direction == "bear")
   {
      for(int i = 1; i <= lookback; i++)
      {
         double h = iHigh(_Symbol, PERIOD_CURRENT, i);
         if(h > original_sl)
         {
            extreme_level = h;
            break;
         }
      }
   }
   else
   {
      for(int i = 1; i <= lookback; i++)
      {
         double l = iLow(_Symbol, PERIOD_CURRENT, i);
         if(l < original_sl)
         {
            extreme_level = l;
            break;
         }
      }
   }
   return extreme_level;
}

//+------------------------------------------------------------------+
//| Send signal alert                                                |
//+------------------------------------------------------------------+
void SendSignalAlert(string message)
{
   Alert(message);
   SendNotification(message);
   Print("STX Edge: ", message);
}

//+------------------------------------------------------------------+
//| Create RR visualization boxes                                    |
//+------------------------------------------------------------------+
void CreateRRBox(string direction, string pattern_label, double entry_price, 
                 double sl_price, double tp_price, double pip40_price, bool is_forming)
{
   datetime t1 = TimeCurrent();
   datetime t2 = t1 + PeriodSeconds(PERIOD_CURRENT) * 3;
   
   string sl_name = GenObjName("RR_SL");
   string tp_name = GenObjName("RR_TP");
   string pip_name = GenObjName("RR_PIP");
   
   // SL box
   if(direction == "bear")
   {
      ObjectCreate(0, sl_name, OBJ_RECTANGLE, 0, t1, sl_price, t2, entry_price);
      ObjectCreate(0, tp_name, OBJ_RECTANGLE, 0, t1, entry_price, t2, tp_price);
   }
   else
   {
      ObjectCreate(0, sl_name, OBJ_RECTANGLE, 0, t1, entry_price, t2, sl_price);
      ObjectCreate(0, tp_name, OBJ_RECTANGLE, 0, t1, tp_price, t2, entry_price);
   }
   ObjectSetInteger(0, sl_name, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, sl_name, OBJPROP_FILL, true);
   ObjectSetInteger(0, sl_name, OBJPROP_BACK, true);
   ObjectSetInteger(0, sl_name, OBJPROP_STYLE, is_forming ? STYLE_DASH : STYLE_SOLID);
   ObjectSetString(0, sl_name, OBJPROP_TEXT, is_forming ? "FORMING" : pattern_label);
   
   ObjectSetInteger(0, tp_name, OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(0, tp_name, OBJPROP_FILL, true);
   ObjectSetInteger(0, tp_name, OBJPROP_BACK, true);
   ObjectSetInteger(0, tp_name, OBJPROP_STYLE, is_forming ? STYLE_DASH : STYLE_SOLID);
   ObjectSetString(0, tp_name, OBJPROP_TEXT, pattern_label);
   
   // 40 pip line
   ObjectCreate(0, pip_name, OBJ_HLINE, 0, 0, pip40_price);
   ObjectSetInteger(0, pip_name, OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(0, pip_name, OBJPROP_STYLE, is_forming ? STYLE_DOT : STYLE_SOLID);
   ObjectSetInteger(0, pip_name, OBJPROP_WIDTH, 1);
   
   // Store in RR array
   if(!is_forming)
   {
      if(direction == "bear" && rr_boxes_bear_count < MAX_RR_BOXES)
      {
         rr_boxes_bear[rr_boxes_bear_count].Init();
         rr_boxes_bear[rr_boxes_bear_count].direction = "bear";
         rr_boxes_bear[rr_boxes_bear_count].sl_level = sl_price;
         rr_boxes_bear[rr_boxes_bear_count].creation_bar = Bars(_Symbol, PERIOD_CURRENT) - 1;
         rr_boxes_bear[rr_boxes_bear_count].obj_sl_name = sl_name;
         rr_boxes_bear[rr_boxes_bear_count].obj_tp_name = tp_name;
         rr_boxes_bear[rr_boxes_bear_count].obj_pip_name = pip_name;
         rr_boxes_bear_count++;
      }
      else if(direction == "bull" && rr_boxes_bull_count < MAX_RR_BOXES)
      {
         rr_boxes_bull[rr_boxes_bull_count].Init();
         rr_boxes_bull[rr_boxes_bull_count].direction = "bull";
         rr_boxes_bull[rr_boxes_bull_count].sl_level = sl_price;
         rr_boxes_bull[rr_boxes_bull_count].creation_bar = Bars(_Symbol, PERIOD_CURRENT) - 1;
         rr_boxes_bull[rr_boxes_bull_count].obj_sl_name = sl_name;
         rr_boxes_bull[rr_boxes_bull_count].obj_tp_name = tp_name;
         rr_boxes_bull[rr_boxes_bull_count].obj_pip_name = pip_name;
         rr_boxes_bull_count++;
      }
   }
   else
   {
      // Store forming RR names for cleanup
      if(direction == "bear")
      {
         bear_forming_rr_obj_sl = sl_name;
         bear_forming_rr_obj_tp = tp_name;
         bear_forming_rr_obj_pip = pip_name;
      }
      else
      {
         bull_forming_rr_obj_sl = sl_name;
         bull_forming_rr_obj_tp = tp_name;
         bull_forming_rr_obj_pip = pip_name;
      }
   }
}

//+------------------------------------------------------------------+
//| Clean up forming RR boxes                                        |
//+------------------------------------------------------------------+
void CleanFormingRR(string direction)
{
   if(direction == "bear")
   {
      if(bear_forming_rr_obj_sl != "") { ObjectDelete(0, bear_forming_rr_obj_sl); bear_forming_rr_obj_sl = ""; }
      if(bear_forming_rr_obj_tp != "") { ObjectDelete(0, bear_forming_rr_obj_tp); bear_forming_rr_obj_tp = ""; }
      if(bear_forming_rr_obj_pip != "") { ObjectDelete(0, bear_forming_rr_obj_pip); bear_forming_rr_obj_pip = ""; }
      bear_forming_rr_bar = -1;
   }
   else
   {
      if(bull_forming_rr_obj_sl != "") { ObjectDelete(0, bull_forming_rr_obj_sl); bull_forming_rr_obj_sl = ""; }
      if(bull_forming_rr_obj_tp != "") { ObjectDelete(0, bull_forming_rr_obj_tp); bull_forming_rr_obj_tp = ""; }
      if(bull_forming_rr_obj_pip != "") { ObjectDelete(0, bull_forming_rr_obj_pip); bull_forming_rr_obj_pip = ""; }
      bull_forming_rr_bar = -1;
   }
}

//+------------------------------------------------------------------+
//| Check RR boxes for SL hits                                       |
//+------------------------------------------------------------------+
void CheckRRBoxes()
{
   double current_high = iHigh(_Symbol, PERIOD_CURRENT, 0);
   double current_low = iLow(_Symbol, PERIOD_CURRENT, 0);
   
   for(int idx = rr_boxes_bear_count - 1; idx >= 0; idx--)
   {
      if(current_high > rr_boxes_bear[idx].sl_level)
      {
         ObjectDelete(0, rr_boxes_bear[idx].obj_sl_name);
         ObjectDelete(0, rr_boxes_bear[idx].obj_tp_name);
         ObjectDelete(0, rr_boxes_bear[idx].obj_pip_name);
         for(int j = idx; j < rr_boxes_bear_count - 1; j++)
            rr_boxes_bear[j] = rr_boxes_bear[j+1];
         rr_boxes_bear_count--;
      }
   }
   
   for(int idx = rr_boxes_bull_count - 1; idx >= 0; idx--)
   {
      if(current_low < rr_boxes_bull[idx].sl_level)
      {
         ObjectDelete(0, rr_boxes_bull[idx].obj_sl_name);
         ObjectDelete(0, rr_boxes_bull[idx].obj_tp_name);
         ObjectDelete(0, rr_boxes_bull[idx].obj_pip_name);
         for(int j = idx; j < rr_boxes_bull_count - 1; j++)
            rr_boxes_bull[j] = rr_boxes_bull[j+1];
         rr_boxes_bull_count--;
      }
   }
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   pip_value = _Point * 10;
   if(SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 3 || SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 5)
      pip_value = _Point * 10;
   else
      pip_value = _Point;
   
   // Initialize arrays
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
      arr_laol_first_bear[i] = false;
      arr_laol_first_bull[i] = false;
      arr_laol_candle_bear[i] = false;
      arr_laol_candle_bull[i] = false;
      arr_tf_h[i] = 0;
      arr_tf_l[i] = 0;
      arr_tf_bt[i] = 0;
      arr_tf_bb[i] = 0;
      arr_tf_t[i] = 0;
      arr_tf_conf[i] = false;
      arr_bear_seq[i].Init();
      arr_bull_seq[i].Init();
      arr_bear_hcs[i] = false;
      arr_bull_hcs[i] = false;
      arr_bear_hcs_forming[i] = false;
      arr_bull_hcs_forming[i] = false;
      arr_last_bear_hcs_time[i] = 0;
      arr_last_bull_hcs_time[i] = 0;
      arr_bear_hcs_broken[i] = false;
      arr_bull_hcs_broken[i] = false;
      arr_bear_hcs_retesting[i] = false;
      arr_bull_hcs_retesting[i] = false;
      arr_bear_third_step[i] = 0;
      arr_bear_third_ref_h[i] = 0;
      arr_bear_third_ref_l[i] = 0;
      arr_bear_third_ref_time[i] = 0;
      arr_bull_third_step[i] = 0;
      arr_bull_third_ref_h[i] = 0;
      arr_bull_third_ref_l[i] = 0;
      arr_bull_third_ref_time[i] = 0;
      arr_bear_laol_step[i] = 0;
      arr_bear_laol_ref_h[i] = 0;
      arr_bear_laol_ref_l[i] = 0;
      arr_bear_laol_ref_time[i] = 0;
      arr_bull_laol_step[i] = 0;
      arr_bull_laol_ref_h[i] = 0;
      arr_bull_laol_ref_l[i] = 0;
      arr_bull_laol_ref_time[i] = 0;
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
      tf_boxes_count[i] = 0;
   }
   
   // Initialize LV
   entry_bear_lv.Init();
   entry_bull_lv.Init();
   scalp_bear_lv.Init();
   scalp_bull_lv.Init();
   intra_bear_lv.Init();
   intra_bull_lv.Init();
   
   bear_laol_count = 0;
   bull_laol_count = 0;
   bear_scalp_laol_count = 0;
   bull_scalp_laol_count = 0;
   bear_intra_laol_count = 0;
   bull_intra_laol_count = 0;
   hcs_boxes_bear_count = 0;
   hcs_boxes_bull_count = 0;
   rr_boxes_bear_count = 0;
   rr_boxes_bull_count = 0;
   
   Print("STX Edge indicator initialized. Monitoring ", TF_COUNT, " timeframes.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up all objects
   ObjectsDeleteAll(0, "STX_");
   Print("STX Edge indicator removed.");
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   if(rates_total < 10) return 0;
   
   // Only process on new bars or first run
   int current_bar = rates_total - 1;
   if(prev_calculated > 0 && prev_calculated == rates_total)
   {
      // Tick update - check RR box SL hits only
      CheckRRBoxes();
      return rates_total;
   }
   
   // Process new bar
   double current_high = high[current_bar];
   double current_low = low[current_bar];
   double current_open = open[current_bar];
   double current_close = close[current_bar];
   
   //=== STEP 1: Get MTF data and calculate patterns ===
   TFBarData tf_data[TF_COUNT];
   int max_tf_idx = InpSoftStart ? TF_COUNT : 16; // Only process up to M20 if not soft start
   
   for(int i = 0; i < max_tf_idx; i++)
   {
      if(GetTFData(i, tf_data[i]))
         CalculatePatterns(i, tf_data[i]);
   }
   
   //=== STEP 2: SN count per category ===
   int entry_sn_bear_count = 0, entry_sn_bull_count = 0;
   int scalp_sn_bear_count = 0, scalp_sn_bull_count = 0;
   int intra_sn_bear_count = 0, intra_sn_bull_count = 0;
   
   for(int i = 0; i < max_tf_idx; i++)
   {
      ENUM_TF_CATEGORY cat = GetCategory(i);
      if(arr_sn_bear[i])
      {
         if(cat == CAT_ENTRY) entry_sn_bear_count++;
         else if(cat == CAT_SCALP) scalp_sn_bear_count++;
         else if(cat == CAT_INTRA) intra_sn_bear_count++;
      }
      if(arr_sn_bull[i])
      {
         if(cat == CAT_ENTRY) entry_sn_bull_count++;
         else if(cat == CAT_SCALP) scalp_sn_bull_count++;
         else if(cat == CAT_INTRA) intra_sn_bull_count++;
      }
   }
   
   //=== STEP 3: Third candle and LAOL step detection ===
   for(int i = 0; i < max_tf_idx; i++)
   {
      ENUM_TF_CATEGORY cat = GetCategory(i);
      if(cat == CAT_NONE) continue;
      
      double i_h = arr_tf_h[i];
      double i_l = arr_tf_l[i];
      datetime i_t = arr_tf_t[i];
      bool i_conf = arr_tf_conf[i];
      
      // Third bear detection
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
      
      // Third bull detection
      if(arr_bull_third_step[i] == 1 && i_conf)
      {
         datetime ref_time = arr_bull_third_ref_time[i];
         if(ref_time > 0 && i_t > ref_time)
         {
            double ref_h = arr_bull_third_ref_h[i];
            double ref_l = arr_bull_third_ref_l[i];
            if(ref_h > 0 && ref_l > 0 && i_l < ref_l && i_h < ref_h)
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
      
      // LAOL step bear
      if(arr_bear_laol_step[i] == 1 && i_conf)
      {
         datetime ref_time = arr_bear_laol_ref_time[i];
         if(ref_time > 0 && i_t > ref_time)
         {
            double ref_h = arr_bear_laol_ref_h[i];
            double ref_l = arr_bear_laol_ref_l[i];
            if(ref_h > 0 && ref_l > 0 && i_h > ref_h && i_l > ref_l)
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
      
      // LAOL step bull
      if(arr_bull_laol_step[i] == 1 && i_conf)
      {
         datetime ref_time = arr_bull_laol_ref_time[i];
         if(ref_time > 0 && i_t > ref_time)
         {
            double ref_h = arr_bull_laol_ref_h[i];
            double ref_l = arr_bull_laol_ref_l[i];
            if(ref_h > 0 && ref_l > 0 && i_h < ref_h && i_l < ref_l)
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
   
   //=== STEP 4: Sequence (TBE) updates, HCS, Box creation & management ===
   for(int i = 0; i < max_tf_idx; i++)
   {
      ENUM_TF_CATEGORY cat = GetCategory(i);
      if(cat == CAT_NONE) continue;
      
      string tf_label = FormatTFLabel(TF_MINUTES[i]);
      bool should_show = (cat == CAT_ENTRY) || (cat == CAT_SCALP) || (cat == CAT_INTRA && InpSoftStart);
      
      double i_h = arr_tf_h[i];
      double i_l = arr_tf_l[i];
      datetime i_t = arr_tf_t[i];
      bool i_conf = arr_tf_conf[i];
      double i_bt = arr_tf_bt[i];
      double i_bb = arr_tf_bb[i];
      
      bool i_fu_bear = arr_fu_bear[i];
      bool i_fu_bull = arr_fu_bull[i];
      bool i_third_bear = arr_third_bear[i];
      bool i_third_bull = arr_third_bull[i];
      bool i_first_bear = arr_first_bear[i];
      bool i_first_bull = arr_first_bull[i];
      bool i_laol_bear = arr_laol_bear[i];
      bool i_laol_bull = arr_laol_bull[i];
      bool i_sn_bear = arr_sn_bear[i];
      bool i_sn_bull = arr_sn_bull[i];
      
      // Sequence updates
      bool i_x3_bear = i_third_bear || i_first_bear;
      bool i_x3_bull = i_third_bull || i_first_bull;
      
      bool bear_tbe = UpdateSeq(arr_bear_seq[i], i_fu_bear, i_x3_bear, i_fu_bull, i_x3_bull, 
                                i_h, i_bt, TF_MINUTES[i], i_conf, true, i_h, i_l);
      bool bull_tbe = UpdateSeq(arr_bull_seq[i], i_fu_bull, i_x3_bull, i_fu_bear, i_x3_bear, 
                                i_l, i_bb, TF_MINUTES[i], i_conf, false, i_h, i_l);
      
      // SN double check
      bool sn_dbl_bear = i_sn_bear && ((cat == CAT_ENTRY && entry_sn_bear_count >= 2) ||
                                        (cat == CAT_SCALP && scalp_sn_bear_count >= 2) ||
                                        (cat == CAT_INTRA && intra_sn_bear_count >= 2));
      bool sn_dbl_bull = i_sn_bull && ((cat == CAT_ENTRY && entry_sn_bull_count >= 2) ||
                                        (cat == CAT_SCALP && scalp_sn_bull_count >= 2) ||
                                        (cat == CAT_INTRA && intra_sn_bull_count >= 2));
      
      // HCS detection
      bool bear_hcs = false, bull_hcs = false;
      bool bear_hcs_forming = false, bull_hcs_forming = false;
      
      if(should_show)
      {
         bool new_bear_fu_sn = i_fu_bear || i_sn_bear;
         bool new_bull_fu_sn = i_fu_bull || i_sn_bull;
         
         if(tf_boxes_count[i] > 0 && (new_bear_fu_sn || new_bull_fu_sn))
         {
            for(int bx_idx = 0; bx_idx < tf_boxes_count[i]; bx_idx++)
            {
               if(tf_boxes[i][bx_idx].tf_minutes != TF_MINUTES[i] || tf_boxes[i][bx_idx].creation_time == i_t || tf_boxes[i][bx_idx].state == STATE_FORMING)
                  continue;
               
               bool bx_has_fu_sn = (StringFind(tf_boxes[i][bx_idx].base_pattern, "FU") >= 0) || (StringFind(tf_boxes[i][bx_idx].base_pattern, "SN") >= 0);
               if(!bx_has_fu_sn) continue;
               
               if(tf_boxes[i][bx_idx].direction == "bear" && new_bear_fu_sn)
               {
                  if(i_h > 0 && i_h >= tf_boxes[i][bx_idx].bottom_val && i_h <= tf_boxes[i][bx_idx].original_top)
                  {
                     if(i_conf)
                     {
                        if(arr_last_bear_hcs_time[i] != i_t)
                        {
                           bear_hcs = true;
                           tf_boxes[i][bx_idx].hcs_count++;
                           tf_boxes[i][bx_idx].pattern_text = tf_boxes[i][bx_idx].base_pattern + " [HCS X" + IntegerToString(tf_boxes[i][bx_idx].hcs_count) + "]";
                           arr_last_bear_hcs_time[i] = i_t;
                           
                           if(InpShowHCSBoxes && tf_boxes[i][bx_idx].hcs_count == 1 && (TF_MINUTES[i] == 50 || TF_MINUTES[i] == 60))
                           {
                              if(hcs_boxes_bear_count < MAX_HCS_BOXES)
                              {
                                 hcs_boxes_bear[hcs_boxes_bear_count].Init();
                                 hcs_boxes_bear[hcs_boxes_bear_count].top_val = tf_boxes[i][bx_idx].original_top;
                                 hcs_boxes_bear[hcs_boxes_bear_count].bottom_val = tf_boxes[i][bx_idx].original_bottom;
                                 hcs_boxes_bear[hcs_boxes_bear_count].creation_bar = current_bar;
                                 hcs_boxes_bear[hcs_boxes_bear_count].tf_label = tf_label;
                                 hcs_boxes_bear[hcs_boxes_bear_count].direction = "bear";
                                 hcs_boxes_bear[hcs_boxes_bear_count].is_broken = false;
                                 hcs_boxes_bear_count++;
                              }
                           }
                        }
                     }
                     else
                        bear_hcs_forming = true;
                  }
               }
               if(tf_boxes[i][bx_idx].direction == "bull" && new_bull_fu_sn)
               {
                  if(i_l > 0 && i_l <= tf_boxes[i][bx_idx].top_val && i_l >= tf_boxes[i][bx_idx].original_bottom)
                  {
                     if(i_conf)
                     {
                        if(arr_last_bull_hcs_time[i] != i_t)
                        {
                           bull_hcs = true;
                           tf_boxes[i][bx_idx].hcs_count++;
                           tf_boxes[i][bx_idx].pattern_text = tf_boxes[i][bx_idx].base_pattern + " [HCS X" + IntegerToString(tf_boxes[i][bx_idx].hcs_count) + "]";
                           arr_last_bull_hcs_time[i] = i_t;
                           
                           if(InpShowHCSBoxes && tf_boxes[i][bx_idx].hcs_count == 1 && (TF_MINUTES[i] == 50 || TF_MINUTES[i] == 60))
                           {
                              if(hcs_boxes_bull_count < MAX_HCS_BOXES)
                              {
                                 hcs_boxes_bull[hcs_boxes_bull_count].Init();
                                 hcs_boxes_bull[hcs_boxes_bull_count].top_val = tf_boxes[i][bx_idx].original_top;
                                 hcs_boxes_bull[hcs_boxes_bull_count].bottom_val = tf_boxes[i][bx_idx].original_bottom;
                                 hcs_boxes_bull[hcs_boxes_bull_count].creation_bar = current_bar;
                                 hcs_boxes_bull[hcs_boxes_bull_count].tf_label = tf_label;
                                 hcs_boxes_bull[hcs_boxes_bull_count].direction = "bull";
                                 hcs_boxes_bull[hcs_boxes_bull_count].is_broken = false;
                                 hcs_boxes_bull_count++;
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
         
         // Build pattern strings and create boxes
         string bear_pattern = BuildPatternStr(true, i_third_bear, i_first_bear, i_laol_bear, 
                                               i_sn_bear, sn_dbl_bear, i_fu_bear, bear_tbe, bear_hcs, bear_hcs_forming);
         string bull_pattern = BuildPatternStr(false, i_third_bull, i_first_bull, i_laol_bull, 
                                               i_sn_bull, sn_dbl_bull, i_fu_bull, bull_tbe, bull_hcs, bull_hcs_forming);
         
         if(bear_pattern != "" && i_h > 0 && i_bt > 0 && i_t > 0)
            CreateBox(i, "bear", i_h, i_bt, i_t, bear_pattern, TF_MINUTES[i], cat == CAT_INTRA);
         if(bull_pattern != "" && i_l > 0 && i_bb > 0 && i_t > 0)
            CreateBox(i, "bull", i_bb, i_l, i_t, bull_pattern, TF_MINUTES[i], cat == CAT_INTRA);
         
         // Manage boxes (retesting/state transitions)
         bool bear_ret, bull_ret, bear_est_r, bull_est_r, bear_est_v, bull_est_v;
         string bear_pat, bull_pat;
         double bear_lvl, bull_lvl;
         ManageTFBoxes(i, i_h, i_l, i_t, i_conf, TF_MINUTES[i],
                       bear_ret, bull_ret, bear_pat, bull_pat, bear_lvl, bull_lvl,
                       bear_est_r, bull_est_r, bear_est_v, bull_est_v);
         
         arr_bear_retesting[i] = bear_ret;
         arr_bull_retesting[i] = bull_ret;
         arr_bear_retest_pattern[i] = bear_pat;
         arr_bull_retest_pattern[i] = bull_pat;
         arr_bear_retest_level[i] = bear_lvl;
         arr_bull_retest_level[i] = bull_lvl;
         arr_bear_est_retest[i] = bear_est_r;
         arr_bull_est_retest[i] = bull_est_r;
         arr_bear_est_retest_VALID[i] = bear_est_v;
         arr_bull_est_retest_VALID[i] = bull_est_v;
      }
      
      // LAOL candle detection and line creation
      if(cat == CAT_ENTRY && should_show && i_conf)
      {
         if(arr_laol_candle_bear[i])
         {
            if(!MergeCrossCategory(bear_laol_lines, bear_laol_count, 
                                   bear_scalp_laol_lines, bear_scalp_laol_count,
                                   bear_intra_laol_lines, bear_intra_laol_count,
                                   i_h, tf_label, true))
               AddOrMergeLaolLine(bear_laol_lines, bear_laol_count, i_h, tf_label, true, "ENTRY");
         }
         if(arr_laol_candle_bull[i])
         {
            if(!MergeCrossCategory(bull_laol_lines, bull_laol_count,
                                   bull_scalp_laol_lines, bull_scalp_laol_count,
                                   bull_intra_laol_lines, bull_intra_laol_count,
                                   i_l, tf_label, false))
               AddOrMergeLaolLine(bull_laol_lines, bull_laol_count, i_l, tf_label, false, "ENTRY");
         }
      }
      else if(cat == CAT_SCALP && should_show && i_conf)
      {
         if(arr_laol_candle_bear[i])
         {
            if(!MergeCrossCategory(bear_laol_lines, bear_laol_count,
                                   bear_scalp_laol_lines, bear_scalp_laol_count,
                                   bear_intra_laol_lines, bear_intra_laol_count,
                                   i_h, tf_label, true))
               AddOrMergeLaolLine(bear_scalp_laol_lines, bear_scalp_laol_count, i_h, tf_label, true, "SCALP");
         }
         if(arr_laol_candle_bull[i])
         {
            if(!MergeCrossCategory(bull_laol_lines, bull_laol_count,
                                   bull_scalp_laol_lines, bull_scalp_laol_count,
                                   bull_intra_laol_lines, bull_intra_laol_count,
                                   i_l, tf_label, false))
               AddOrMergeLaolLine(bull_scalp_laol_lines, bull_scalp_laol_count, i_l, tf_label, false, "SCALP");
         }
      }
      else if(cat == CAT_INTRA && i_conf)
      {
         if(arr_laol_candle_bear[i])
         {
            if(!MergeCrossCategory(bear_laol_lines, bear_laol_count,
                                   bear_scalp_laol_lines, bear_scalp_laol_count,
                                   bear_intra_laol_lines, bear_intra_laol_count,
                                   i_h, tf_label, true))
               AddOrMergeLaolLine(bear_intra_laol_lines, bear_intra_laol_count, i_h, tf_label, true, "INTRA");
         }
         if(arr_laol_candle_bull[i])
         {
            if(!MergeCrossCategory(bull_laol_lines, bull_laol_count,
                                   bull_scalp_laol_lines, bull_scalp_laol_count,
                                   bull_intra_laol_lines, bull_intra_laol_count,
                                   i_l, tf_label, false))
               AddOrMergeLaolLine(bull_intra_laol_lines, bull_intra_laol_count, i_l, tf_label, false, "INTRA");
         }
      }
   }
   
   //=== STEP 5: Update LAOL lines ===
   datetime bear_bt = 0, bull_bt = 0;
   string bear_btf = "", bull_btf = "";
   datetime bear_ibt = 0, bull_ibt = 0;
   string bear_ibtf = "", bull_ibtf = "";
   datetime bear_sbt = 0, bull_sbt = 0;
   string bear_sbtf = "", bull_sbtf = "";
   
   UpdateLaolLines(bear_laol_lines, bear_laol_count, true, current_high, bear_bt, bear_btf, bear_ibt, bear_ibtf, bear_sbt, bear_sbtf);
   UpdateLaolLines(bull_laol_lines, bull_laol_count, false, current_low, bull_bt, bull_btf, bull_ibt, bull_ibtf, bull_sbt, bull_sbtf);
   
   if(bear_bt > 0) { last_bear_laol_break_time = bear_bt; last_bear_laol_tf = bear_btf; }
   if(bull_bt > 0) { last_bull_laol_break_time = bull_bt; last_bull_laol_tf = bull_btf; }
   if(bear_ibt > 0) { last_bear_intra_laol_break_time = bear_ibt; last_bear_intra_laol_tf = bear_ibtf; }
   if(bull_ibt > 0) { last_bull_intra_laol_break_time = bull_ibt; last_bull_intra_laol_tf = bull_ibtf; }
   if(bear_sbt > 0) { last_bear_scalp_laol_break_time = bear_sbt; last_bear_scalp_laol_tf = bear_sbtf; }
   if(bull_sbt > 0) { last_bull_scalp_laol_break_time = bull_sbt; last_bull_scalp_laol_tf = bull_sbtf; }
   
   // Update scalp LAOL lines
   datetime bear_bt2 = 0, bull_bt2 = 0;
   string bear_btf2 = "", bull_btf2 = "";
   datetime bear_ibt2 = 0, bull_ibt2 = 0;
   string bear_ibtf2 = "", bull_ibtf2 = "";
   datetime bear_sbt2 = 0, bull_sbt2 = 0;
   string bear_sbtf2 = "", bull_sbtf2 = "";
   
   UpdateLaolLines(bear_scalp_laol_lines, bear_scalp_laol_count, true, current_high, bear_bt2, bear_btf2, bear_ibt2, bear_ibtf2, bear_sbt2, bear_sbtf2);
   UpdateLaolLines(bull_scalp_laol_lines, bull_scalp_laol_count, false, current_low, bull_bt2, bull_btf2, bull_ibt2, bull_ibtf2, bull_sbt2, bull_sbtf2);
   
   if(bear_ibt2 > 0) { last_bear_intra_laol_break_time = bear_ibt2; last_bear_intra_laol_tf = bear_ibtf2; }
   if(bull_ibt2 > 0) { last_bull_intra_laol_break_time = bull_ibt2; last_bull_intra_laol_tf = bull_ibtf2; }
   if(bear_sbt2 > 0) { last_bear_scalp_laol_break_time = bear_sbt2; last_bear_scalp_laol_tf = bear_sbtf2; }
   if(bull_sbt2 > 0) { last_bull_scalp_laol_break_time = bull_sbt2; last_bull_scalp_laol_tf = bull_sbtf2; }
   
   // Update intra LAOL lines
   datetime bear_bt3 = 0, bull_bt3 = 0;
   string bear_btf3 = "", bull_btf3 = "";
   datetime bear_ibt3 = 0, bull_ibt3 = 0;
   string bear_ibtf3 = "", bull_ibtf3 = "";
   datetime bear_sbt3 = 0, bull_sbt3 = 0;
   string bear_sbtf3 = "", bull_sbtf3 = "";
   
   UpdateLaolLines(bear_intra_laol_lines, bear_intra_laol_count, true, current_high, bear_bt3, bear_btf3, bear_ibt3, bear_ibtf3, bear_sbt3, bear_sbtf3);
   UpdateLaolLines(bull_intra_laol_lines, bull_intra_laol_count, false, current_low, bull_bt3, bull_btf3, bull_ibt3, bull_ibtf3, bull_sbt3, bull_sbtf3);
   
   if(bear_ibt3 > 0) { last_bear_intra_laol_break_time = bear_ibt3; last_bear_intra_laol_tf = bear_ibtf3; }
   if(bull_ibt3 > 0) { last_bull_intra_laol_break_time = bull_ibt3; last_bull_intra_laol_tf = bull_ibtf3; }
   
   //=== STEP 6: Manage HCS boxes ===
   if(InpShowHCSBoxes)
   {
      ManageHCSBoxes(hcs_boxes_bear, hcs_boxes_bear_count, true);
      ManageHCSBoxes(hcs_boxes_bull, hcs_boxes_bull_count, false);
   }
   
   //=== STEP 7: Calculate LV (Last Valid) for each category ===
   int entry_bear_em_forming = 0, entry_bull_em_forming = 0;
   int entry_bear_em_est = 0, entry_bull_em_est = 0;
   int entry_bear_em_ret = 0, entry_bull_em_ret = 0;
   int entry_bear_hcs_m1 = 0, entry_bull_hcs_m1 = 0;
   int scalp_bear_em_forming = 0, scalp_bull_em_forming = 0;
   int scalp_bear_em_est = 0, scalp_bull_em_est = 0;
   int scalp_bear_em_ret = 0, scalp_bull_em_ret = 0;
   int intra_bear_em_forming = 0, intra_bull_em_forming = 0;
   int intra_bear_em_total = 0, intra_bull_em_total = 0;
   bool intra_bear_retesting = false, intra_bull_retesting = false;
   bool intra_bear_est_ret_dir_found = false, intra_bull_est_ret_dir_found = false;
   bool intra_bear_est_ret_box_found = false, intra_bull_est_ret_box_found = false;
   bool intra_bear_em_form_found = false, intra_bull_em_form_found = false;
   bool intra_bear_hcs_ret = false, intra_bull_hcs_ret = false;
   
   for(int i = 0; i < max_tf_idx; i++)
   {
      ENUM_TF_CATEGORY cat = GetCategory(i);
      if(cat == CAT_NONE) continue;
      
      string tf_label = FormatTFLabel(TF_MINUTES[i]);
      bool i_conf = arr_tf_conf[i];
      double i_h = arr_tf_h[i];
      double i_l = arr_tf_l[i];
      
      bool i_third_bear = arr_third_bear[i];
      bool i_third_bull = arr_third_bull[i];
      bool i_first_bear = arr_first_bear[i];
      bool i_first_bull = arr_first_bull[i];
      bool i_laol_bear_v = arr_laol_bear[i];
      bool i_laol_bull_v = arr_laol_bull[i];
      bool i_sn_bear = arr_sn_bear[i];
      bool i_sn_bull = arr_sn_bull[i];
      bool bear_hcs_v = arr_bear_hcs[i];
      bool bull_hcs_v = arr_bull_hcs[i];
      bool bear_hcs_form = arr_bear_hcs_forming[i];
      bool bull_hcs_form = arr_bull_hcs_forming[i];
      bool bear_tbe_v = (arr_bear_seq[i].step == 5);
      bool bull_tbe_v = (arr_bull_seq[i].step == 5);
      
      bool sn_dbl_bear = i_sn_bear && ((cat == CAT_ENTRY && entry_sn_bear_count >= 2) ||
                                        (cat == CAT_SCALP && scalp_sn_bear_count >= 2) ||
                                        (cat == CAT_INTRA && intra_sn_bear_count >= 2));
      bool sn_dbl_bull = i_sn_bull && ((cat == CAT_ENTRY && entry_sn_bull_count >= 2) ||
                                        (cat == CAT_SCALP && scalp_sn_bull_count >= 2) ||
                                        (cat == CAT_INTRA && intra_sn_bull_count >= 2));
      
      bool bear_is_em = i_third_bear || i_first_bear || i_laol_bear_v || sn_dbl_bear || bear_tbe_v || bear_hcs_v || bear_hcs_form;
      bool bull_is_em = i_third_bull || i_first_bull || i_laol_bull_v || sn_dbl_bull || bull_tbe_v || bull_hcs_v || bull_hcs_form;
      
      if(!i_conf)
      {
         if(cat == CAT_ENTRY) { if(bear_is_em) entry_bear_em_forming++; if(bull_is_em) entry_bull_em_forming++; }
         else if(cat == CAT_SCALP) { if(bear_is_em) scalp_bear_em_forming++; if(bull_is_em) scalp_bull_em_forming++; }
         else if(cat == CAT_INTRA) { if(bear_is_em) intra_bear_em_forming++; if(bull_is_em) intra_bull_em_forming++; }
      }
      
      // Scan boxes for LV, retesting counts
      for(int bx_idx = 0; bx_idx < tf_boxes_count[i]; bx_idx++)
      {
         bool is_em = IsEMPattern(tf_boxes[i][bx_idx].base_pattern);
         bool is_fu_sn = IsFUPattern(tf_boxes[i][bx_idx].base_pattern);
         bool should_check = (cat == CAT_SCALP) ? (is_em || is_fu_sn) : is_em;
         if(!should_check) continue;
         
         bool is_active = (tf_boxes[i][bx_idx].state == STATE_FORMING || tf_boxes[i][bx_idx].state == STATE_ESTABLISHED || 
                          tf_boxes[i][bx_idx].state == STATE_EST_RETEST || tf_boxes[i][bx_idx].state == STATE_RESPECTED);
         if(!is_active) continue;
         
         bool has_em_modifier = (StringFind(tf_boxes[i][bx_idx].base_pattern, "Third") >= 0) || 
                                (StringFind(tf_boxes[i][bx_idx].base_pattern, "First") >= 0) || 
                                (StringFind(tf_boxes[i][bx_idx].base_pattern, "LAOL") >= 0) || 
                                (StringFind(tf_boxes[i][bx_idx].base_pattern, "[EM]") >= 0) || 
                                (StringFind(tf_boxes[i][bx_idx].base_pattern, "TBE") >= 0) || 
                                (StringFind(tf_boxes[i][bx_idx].base_pattern, "HCS") >= 0);
         
         bool bear_touching = (tf_boxes[i][bx_idx].direction == "bear" && i_h > 0 && i_h >= tf_boxes[i][bx_idx].bottom_val && i_h <= tf_boxes[i][bx_idx].top_val);
         bool bull_touching = (tf_boxes[i][bx_idx].direction == "bull" && i_l > 0 && i_l <= tf_boxes[i][bx_idx].top_val && i_l >= tf_boxes[i][bx_idx].bottom_val);
         
         if(tf_boxes[i][bx_idx].direction == "bear")
         {
            if(cat == CAT_ENTRY)
            {
               if(is_active && is_em) entry_bear_em_est++;
               if(bear_touching && tf_boxes[i][bx_idx].state != STATE_EST_RETEST && tf_boxes[i][bx_idx].state != STATE_FORMING) entry_bear_em_ret++;
               if(is_em && has_em_modifier && tf_boxes[i][bx_idx].state == STATE_ESTABLISHED && tf_boxes[i][bx_idx].creation_time > entry_bear_lv.est_time)
               {
                  entry_bear_lv.pattern_text = "[" + tf_label + "] " + tf_boxes[i][bx_idx].pattern_text;
                  entry_bear_lv.original_text = "[" + tf_label + "] " + tf_boxes[i][bx_idx].pattern_text;
                  entry_bear_lv.level = tf_boxes[i][bx_idx].original_top;
                  entry_bear_lv.est_time = tf_boxes[i][bx_idx].creation_time;
                  entry_bear_lv.direction = "bear";
                  entry_bear_lv.is_broken = false;
               }
            }
            else if(cat == CAT_SCALP)
            {
               if(is_active && is_em) scalp_bear_em_est++;
               if(bear_touching && (is_em || is_fu_sn) && tf_boxes[i][bx_idx].state != STATE_EST_RETEST && tf_boxes[i][bx_idx].state != STATE_FORMING) scalp_bear_em_ret++;
               if(is_em && has_em_modifier && tf_boxes[i][bx_idx].state == STATE_ESTABLISHED && tf_boxes[i][bx_idx].creation_time > scalp_bear_lv.est_time)
               {
                  scalp_bear_lv.pattern_text = "[" + tf_label + "] " + tf_boxes[i][bx_idx].pattern_text;
                  scalp_bear_lv.original_text = "[" + tf_label + "] " + tf_boxes[i][bx_idx].pattern_text;
                  scalp_bear_lv.level = tf_boxes[i][bx_idx].original_top;
                  scalp_bear_lv.est_time = tf_boxes[i][bx_idx].creation_time;
                  scalp_bear_lv.direction = "bear";
                  scalp_bear_lv.is_broken = false;
               }
            }
            else if(cat == CAT_INTRA)
            {
               if(is_active && is_em) intra_bear_em_total++;
               if(bear_touching && is_em && tf_boxes[i][bx_idx].state != STATE_EST_RETEST && tf_boxes[i][bx_idx].state != STATE_FORMING) intra_bear_retesting = true;
               if(is_em && has_em_modifier && tf_boxes[i][bx_idx].state == STATE_ESTABLISHED && tf_boxes[i][bx_idx].creation_time > intra_bear_lv.est_time)
               {
                  intra_bear_lv.pattern_text = "[" + tf_label + "] " + tf_boxes[i][bx_idx].pattern_text;
                  intra_bear_lv.original_text = "[" + tf_label + "] " + tf_boxes[i][bx_idx].pattern_text;
                  intra_bear_lv.level = tf_boxes[i][bx_idx].original_top;
                  intra_bear_lv.est_time = tf_boxes[i][bx_idx].creation_time;
                  intra_bear_lv.direction = "bear";
                  intra_bear_lv.is_broken = false;
               }
               if(tf_boxes[i][bx_idx].has_est_retest && (tf_boxes[i][bx_idx].state == STATE_EST_RETEST || (tf_boxes[i][bx_idx].state == STATE_RESPECTED && tf_boxes[i][bx_idx].completed_est_retest)))
                  intra_bear_est_ret_box_found = true;
               if(tf_boxes[i][bx_idx].is_em_forming && (tf_boxes[i][bx_idx].state == STATE_FORMING || tf_boxes[i][bx_idx].state == STATE_ESTABLISHED))
                  intra_bear_em_form_found = true;
            }
         }
         else // bull
         {
            if(cat == CAT_ENTRY)
            {
               if(is_active && is_em) entry_bull_em_est++;
               if(bull_touching && tf_boxes[i][bx_idx].state != STATE_EST_RETEST && tf_boxes[i][bx_idx].state != STATE_FORMING) entry_bull_em_ret++;
               if(is_em && has_em_modifier && tf_boxes[i][bx_idx].state == STATE_ESTABLISHED && tf_boxes[i][bx_idx].creation_time > entry_bull_lv.est_time)
               {
                  entry_bull_lv.pattern_text = "[" + tf_label + "] " + tf_boxes[i][bx_idx].pattern_text;
                  entry_bull_lv.original_text = "[" + tf_label + "] " + tf_boxes[i][bx_idx].pattern_text;
                  entry_bull_lv.level = tf_boxes[i][bx_idx].original_bottom;
                  entry_bull_lv.est_time = tf_boxes[i][bx_idx].creation_time;
                  entry_bull_lv.direction = "bull";
                  entry_bull_lv.is_broken = false;
               }
            }
            else if(cat == CAT_SCALP)
            {
               if(is_active && is_em) scalp_bull_em_est++;
               if(bull_touching && (is_em || is_fu_sn) && tf_boxes[i][bx_idx].state != STATE_EST_RETEST && tf_boxes[i][bx_idx].state != STATE_FORMING) scalp_bull_em_ret++;
               if(is_em && has_em_modifier && tf_boxes[i][bx_idx].state == STATE_ESTABLISHED && tf_boxes[i][bx_idx].creation_time > scalp_bull_lv.est_time)
               {
                  scalp_bull_lv.pattern_text = "[" + tf_label + "] " + tf_boxes[i][bx_idx].pattern_text;
                  scalp_bull_lv.original_text = "[" + tf_label + "] " + tf_boxes[i][bx_idx].pattern_text;
                  scalp_bull_lv.level = tf_boxes[i][bx_idx].original_bottom;
                  scalp_bull_lv.est_time = tf_boxes[i][bx_idx].creation_time;
                  scalp_bull_lv.direction = "bull";
                  scalp_bull_lv.is_broken = false;
               }
            }
            else if(cat == CAT_INTRA)
            {
               if(is_active && is_em) intra_bull_em_total++;
               if(bull_touching && is_em && tf_boxes[i][bx_idx].state != STATE_EST_RETEST && tf_boxes[i][bx_idx].state != STATE_FORMING) intra_bull_retesting = true;
               if(is_em && has_em_modifier && tf_boxes[i][bx_idx].state == STATE_ESTABLISHED && tf_boxes[i][bx_idx].creation_time > intra_bull_lv.est_time)
               {
                  intra_bull_lv.pattern_text = "[" + tf_label + "] " + tf_boxes[i][bx_idx].pattern_text;
                  intra_bull_lv.original_text = "[" + tf_label + "] " + tf_boxes[i][bx_idx].pattern_text;
                  intra_bull_lv.level = tf_boxes[i][bx_idx].original_bottom;
                  intra_bull_lv.est_time = tf_boxes[i][bx_idx].creation_time;
                  intra_bull_lv.direction = "bull";
                  intra_bull_lv.is_broken = false;
               }
               if(tf_boxes[i][bx_idx].has_est_retest && (tf_boxes[i][bx_idx].state == STATE_EST_RETEST || (tf_boxes[i][bx_idx].state == STATE_RESPECTED && tf_boxes[i][bx_idx].completed_est_retest)))
                  intra_bull_est_ret_box_found = true;
               if(tf_boxes[i][bx_idx].is_em_forming && (tf_boxes[i][bx_idx].state == STATE_FORMING || tf_boxes[i][bx_idx].state == STATE_ESTABLISHED))
                  intra_bull_em_form_found = true;
            }
         }
      }
      
      // EST retest counts per category
      if(cat == CAT_INTRA)
      {
         if(arr_bear_est_retest[i]) intra_bear_est_ret_dir_found = true;
         if(arr_bull_est_retest[i]) intra_bull_est_ret_dir_found = true;
      }
   }
   
   //=== STEP 8: Check LV breaks ===
   CheckBreak(entry_bear_lv, current_high, current_low);
   CheckBreak(entry_bull_lv, current_high, current_low);
   CheckBreak(scalp_bear_lv, current_high, current_low);
   CheckBreak(scalp_bull_lv, current_high, current_low);
   CheckBreak(intra_bear_lv, current_high, current_low);
   CheckBreak(intra_bull_lv, current_high, current_low);
   
   // Resolve LV
   string entry_lv_text, entry_lv_dir, entry_lv_orig_dir;
   bool entry_lv_broken;
   ResolveLV(entry_bear_lv, entry_bull_lv, entry_lv_text, entry_lv_dir, entry_lv_orig_dir, entry_lv_broken);
   
   string scalp_lv_text, scalp_lv_dir, scalp_lv_orig_dir;
   bool scalp_lv_broken;
   ResolveLV(scalp_bear_lv, scalp_bull_lv, scalp_lv_text, scalp_lv_dir, scalp_lv_orig_dir, scalp_lv_broken);
   
   string intra_lv_text, intra_lv_dir, intra_lv_orig_dir;
   bool intra_lv_broken;
   ResolveLV(intra_bear_lv, intra_bull_lv, intra_lv_text, intra_lv_dir, intra_lv_orig_dir, intra_lv_broken);
   
   //=== STEP 9: Intra Negation Detection ===
   intra_bear_negating = false;
   intra_bull_negating = false;
   intra_bear_negating_pattern = "";
   intra_bull_negating_pattern = "";
   
   bool check_bear_neg = (intra_lv_dir == "bull" && !intra_lv_broken);
   bool check_bull_neg = (intra_lv_dir == "bear" && !intra_lv_broken);
   
   if(check_bear_neg || check_bull_neg)
   {
      for(int i = INTRA_MIN_IDX; i <= INTRA_MAX_IDX && i < max_tf_idx; i++)
      {
         if(intra_bear_negating && intra_bull_negating) break;
         
         string tf_label = FormatTFLabel(TF_MINUTES[i]);
         bool i_conf = arr_tf_conf[i];
         
         if(check_bear_neg && !intra_bear_negating)
         {
            bool i_third_bear = arr_third_bear[i];
            bool i_first_bear = arr_first_bear[i];
            bool i_laol_bear_v = arr_laol_bear[i];
            bool i_sn_bear = arr_sn_bear[i];
            bool i_bear_hcs_v = arr_bear_hcs[i];
            bool i_bear_hcs_form = arr_bear_hcs_forming[i];
            bool bear_tbe_v = (arr_bear_seq[i].step == 5);
            bool sn_dbl_bear = i_sn_bear && (intra_sn_bear_count >= 2);
            
            bool bear_em_detected = i_third_bear || i_first_bear || i_laol_bear_v || sn_dbl_bear || bear_tbe_v || i_bear_hcs_v || i_bear_hcs_form;
            if(bear_em_detected)
            {
               intra_bear_negating = true;
               string bear_pattern = BuildPatternStr(true, i_third_bear, i_first_bear, i_laol_bear_v,
                                                    i_sn_bear, sn_dbl_bear, false, bear_tbe_v, i_bear_hcs_v, i_bear_hcs_form);
               string conf_status = i_conf ? "" : " [FORMING]";
               intra_bear_negating_pattern = "[" + tf_label + "] " + bear_pattern + conf_status;
            }
         }
         
         if(check_bull_neg && !intra_bull_negating)
         {
            bool i_third_bull = arr_third_bull[i];
            bool i_first_bull = arr_first_bull[i];
            bool i_laol_bull_v = arr_laol_bull[i];
            bool i_sn_bull = arr_sn_bull[i];
            bool i_bull_hcs_v = arr_bull_hcs[i];
            bool i_bull_hcs_form = arr_bull_hcs_forming[i];
            bool bull_tbe_v = (arr_bull_seq[i].step == 5);
            bool sn_dbl_bull = i_sn_bull && (intra_sn_bull_count >= 2);
            
            bool bull_em_detected = i_third_bull || i_first_bull || i_laol_bull_v || sn_dbl_bull || bull_tbe_v || i_bull_hcs_v || i_bull_hcs_form;
            if(bull_em_detected)
            {
               intra_bull_negating = true;
               string bull_pattern = BuildPatternStr(false, i_third_bull, i_first_bull, i_laol_bull_v,
                                                    i_sn_bull, sn_dbl_bull, false, bull_tbe_v, i_bull_hcs_v, i_bull_hcs_form);
               string conf_status = i_conf ? "" : " [FORMING]";
               intra_bull_negating_pattern = "[" + tf_label + "] " + bull_pattern + conf_status;
            }
         }
      }
   }
   
   //=== STEP 10: Final Entry Logic ===
   // Check base conditions (S1-S4)
   bool bear_base_valid = false;
   string bear_base_type = "";
   
   if(entry_lv_dir == "bear" && !entry_lv_broken && scalp_lv_dir == "bear" && !scalp_lv_broken)
   {
      int scalp_bear_total = scalp_bear_em_est + scalp_bear_em_forming;
      int entry_bear_total = entry_bear_em_est + entry_bear_em_forming;
      
      bool s1 = (scalp_bear_total > 0 && entry_bear_total > 0 && entry_bear_em_ret > 0);
      bool s2 = (scalp_bear_total > 0 && scalp_bear_em_ret > 0 && entry_bear_total > 0 && entry_bear_em_ret > 0);
      bool s3 = (scalp_bear_em_forming >= 1 && entry_bear_total > 0 && entry_bear_em_ret > 0);
      bool s4 = (entry_bear_hcs_m1 >= 1);
      
      bear_base_valid = s1 || s2 || s3 || s4;
      if(s4) bear_base_type = "S4";
      else
      {
         if(s1) bear_base_type = "S1";
         if(s2) bear_base_type += (bear_base_type != "" ? "+" : "") + "S2";
         if(s3) bear_base_type += (bear_base_type != "" ? "+" : "") + "S3";
      }
   }
   
   bool bull_base_valid = false;
   string bull_base_type = "";
   
   if(entry_lv_dir == "bull" && !entry_lv_broken && scalp_lv_dir == "bull" && !scalp_lv_broken)
   {
      int scalp_bull_total = scalp_bull_em_est + scalp_bull_em_forming;
      int entry_bull_total = entry_bull_em_est + entry_bull_em_forming;
      
      bool s1 = (scalp_bull_total > 0 && entry_bull_total > 0 && entry_bull_em_ret > 0);
      bool s2 = (scalp_bull_total > 0 && scalp_bull_em_ret > 0 && entry_bull_total > 0 && entry_bull_em_ret > 0);
      bool s3 = (scalp_bull_em_forming >= 1 && entry_bull_total > 0 && entry_bull_em_ret > 0);
      bool s4 = (entry_bull_hcs_m1 >= 1);
      
      bull_base_valid = s1 || s2 || s3 || s4;
      if(s4) bull_base_type = "S4";
      else
      {
         if(s1) bull_base_type = "S1";
         if(s2) bull_base_type += (bull_base_type != "" ? "+" : "") + "S2";
         if(s3) bull_base_type += (bull_base_type != "" ? "+" : "") + "S3";
      }
   }
   
   // Intra conditions
   bool bear_intra_est_valid = false, bear_intra_em_valid = false;
   bool bear_intra_lv_valid = false, bear_intra_neg_valid = false, bear_zone_valid = false;
   
   if(bear_base_valid)
   {
      bear_intra_est_valid = (intra_lv_dir == "bear" && !intra_lv_broken && intra_bear_est_ret_dir_found && intra_bear_est_ret_box_found);
      bear_intra_em_valid = (intra_lv_dir == "bear" && !intra_lv_broken && intra_bear_em_form_found);
      bear_intra_lv_valid = (intra_lv_dir == "bear" && !intra_lv_broken);
      bool bear_neg_hcs_condition = intra_bear_hcs_ret || intra_bull_hcs_ret || 
                                    (intra_bear_em_form_found && StringFind(intra_bear_negating_pattern, "HCS") >= 0);
      bear_intra_neg_valid = (intra_lv_orig_dir == "bull" && !intra_lv_broken && intra_bear_negating && bear_neg_hcs_condition);
      bear_zone_valid = (intra_bear_hcs_ret && intra_bear_negating);
   }
   
   bool bull_intra_est_valid = false, bull_intra_em_valid = false;
   bool bull_intra_lv_valid = false, bull_intra_neg_valid = false, bull_zone_valid = false;
   
   if(bull_base_valid)
   {
      bull_intra_est_valid = (intra_lv_dir == "bull" && !intra_lv_broken && intra_bull_est_ret_dir_found && intra_bull_est_ret_box_found);
      bull_intra_em_valid = (intra_lv_dir == "bull" && !intra_lv_broken && intra_bull_em_form_found);
      bull_intra_lv_valid = (intra_lv_dir == "bull" && !intra_lv_broken);
      bool bull_neg_hcs_condition = intra_bear_hcs_ret || intra_bull_hcs_ret || 
                                    (intra_bull_em_form_found && StringFind(intra_bull_negating_pattern, "HCS") >= 0);
      bull_intra_neg_valid = (intra_lv_orig_dir == "bear" && !intra_lv_broken && intra_bull_negating && bull_neg_hcs_condition);
      bull_zone_valid = (intra_bull_hcs_ret && intra_bull_negating);
   }
   
   // M1 confirmed check
   bool m1_conf = arr_tf_conf[0];
   
   // Forming/Confirmed signals
   bool bear_base_forming = bear_base_valid && !m1_conf && InpShowSetupsS1S4;
   bool bear_base_confirmed = bear_base_valid && m1_conf && InpShowSetupsS1S4;
   bool bear_intra_est_forming = bear_intra_est_valid && !m1_conf && InpShowIntraEstRetest;
   bool bear_intra_est_confirmed = bear_intra_est_valid && m1_conf && InpShowIntraEstRetest;
   bool bear_intra_em_forming_sig = bear_intra_em_valid && !m1_conf && InpShowIntraEMForming;
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
   bool bull_intra_em_forming_sig = bull_intra_em_valid && !m1_conf && InpShowIntraEMForming;
   bool bull_intra_em_confirmed = bull_intra_em_valid && m1_conf && InpShowIntraEMForming;
   bool bull_intra_lv_forming = bull_intra_lv_valid && !m1_conf && InpShowIntraLVAligned;
   bool bull_intra_lv_confirmed = bull_intra_lv_valid && m1_conf && InpShowIntraLVAligned;
   bool bull_intra_neg_forming = bull_intra_neg_valid && !m1_conf && InpShowIntraNegation;
   bool bull_intra_neg_confirmed = bull_intra_neg_valid && m1_conf && InpShowIntraNegation;
   bool bull_zone_forming = bull_zone_valid && !m1_conf && InpShowIntraNegation;
   bool bull_zone_confirmed = bull_zone_valid && m1_conf && InpShowIntraNegation;
   
   //=== STEP 11: Build setup display and generate alerts ===
   // Determine bear forming type
   bool bear_has_any_intra = bear_zone_forming || bear_zone_confirmed || bear_intra_neg_forming || 
                             bear_intra_neg_confirmed || bear_intra_lv_forming || bear_intra_lv_confirmed || 
                             bear_intra_em_forming_sig || bear_intra_em_confirmed || bear_intra_est_forming || 
                             bear_intra_est_confirmed;
   
   string current_bear_forming = "";
   if(bear_zone_forming)
      current_bear_forming = "INTRA+ZONE [" + bear_base_type + "]";
   else if(bear_intra_neg_forming)
      current_bear_forming = "INTRA+NEG [" + bear_base_type + "]";
   else if(bear_intra_lv_forming)
      current_bear_forming = "INTRA+LV [" + bear_base_type + "]";
   else if(bear_intra_em_forming_sig)
      current_bear_forming = "INTRA+EM [" + bear_base_type + "]";
   else if(bear_intra_est_forming)
      current_bear_forming = "INTRA+EST+RET [" + bear_base_type + "]";
   else if(bear_base_forming && !bear_has_any_intra)
      current_bear_forming = bear_base_type;
   
   // BEAR FORMING alert
   if(current_bear_forming != "" && (bear_forming_rr_bar < 0 || current_bar != bear_forming_rr_bar || current_bear_forming != bear_forming_type_prev))
   {
      CleanFormingRR("bear");
      
      double f_entry = MathMax(current_open, current_close);
      double f_sl = current_high;
      double f_ext_sl = FindNextExtremeCandle("bear", f_sl);
      if(f_ext_sl > 0 && f_ext_sl > f_entry) f_sl = f_ext_sl;
      double f_range = f_sl - f_entry;
      double f_tp = f_entry - (f_range * InpTPMultiplier);
      double f_40pip = f_entry - (InpPipTarget * pip_value);
      
      CreateRRBox("bear", current_bear_forming, f_entry, f_sl, f_tp, f_40pip, true);
      bear_forming_rr_bar = current_bar;
      bear_forming_type_prev = current_bear_forming;
      bear_forming_type = current_bear_forming;
      
      SendSignalAlert("BEAR FORMING | " + current_bear_forming + " | SL=" + DoubleToString(f_sl, _Digits) + " | Entry=" + DoubleToString(f_entry, _Digits));
   }
   
   // BEAR CONFIRMED
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
      CleanFormingRR("bear");
      
      double bear_entry = MathMax(current_open, current_close);
      double bear_sl = current_high;
      double extended_sl = FindNextExtremeCandle("bear", bear_sl);
      if(extended_sl > 0 && extended_sl > bear_entry) bear_sl = extended_sl;
      double box_range = bear_sl - bear_entry;
      double bear_tp = bear_entry - (box_range * InpTPMultiplier);
      double target_40pip = bear_entry - (InpPipTarget * pip_value);
      
      CreateRRBox("bear", bear_confirmed_type, bear_entry, bear_sl, bear_tp, target_40pip, false);
      
      SendSignalAlert("BEAR CONFIRMED | " + bear_confirmed_type + " | SL=" + DoubleToString(bear_sl, _Digits) + " | Entry=" + DoubleToString(bear_entry, _Digits));
   }
   
   // Bull forming type
   bool bull_has_any_intra = bull_zone_forming || bull_zone_confirmed || bull_intra_neg_forming || 
                             bull_intra_neg_confirmed || bull_intra_lv_forming || bull_intra_lv_confirmed || 
                             bull_intra_em_forming_sig || bull_intra_em_confirmed || bull_intra_est_forming || 
                             bull_intra_est_confirmed;
   
   string current_bull_forming = "";
   if(bull_zone_forming)
      current_bull_forming = "INTRA+ZONE [" + bull_base_type + "]";
   else if(bull_intra_neg_forming)
      current_bull_forming = "INTRA+NEG [" + bull_base_type + "]";
   else if(bull_intra_lv_forming)
      current_bull_forming = "INTRA+LV [" + bull_base_type + "]";
   else if(bull_intra_em_forming_sig)
      current_bull_forming = "INTRA+EM [" + bull_base_type + "]";
   else if(bull_intra_est_forming)
      current_bull_forming = "INTRA+EST+RET [" + bull_base_type + "]";
   else if(bull_base_forming && !bull_has_any_intra)
      current_bull_forming = bull_base_type;
   
   // BULL FORMING alert
   if(current_bull_forming != "" && (bull_forming_rr_bar < 0 || current_bar != bull_forming_rr_bar || current_bull_forming != bull_forming_type_prev))
   {
      CleanFormingRR("bull");
      
      double f_entry = MathMin(current_open, current_close);
      double f_sl = current_low;
      double f_ext_sl = FindNextExtremeCandle("bull", f_sl);
      if(f_ext_sl > 0 && f_ext_sl < f_entry) f_sl = f_ext_sl;
      double f_range = f_entry - f_sl;
      double f_tp = f_entry + (f_range * InpTPMultiplier);
      double f_40pip = f_entry + (InpPipTarget * pip_value);
      
      CreateRRBox("bull", current_bull_forming, f_entry, f_sl, f_tp, f_40pip, true);
      bull_forming_rr_bar = current_bar;
      bull_forming_type_prev = current_bull_forming;
      bull_forming_type = current_bull_forming;
      
      SendSignalAlert("BULL FORMING | " + current_bull_forming + " | SL=" + DoubleToString(f_sl, _Digits) + " | Entry=" + DoubleToString(f_entry, _Digits));
   }
   
   // BULL CONFIRMED
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
      CleanFormingRR("bull");
      
      double bull_entry = MathMin(current_open, current_close);
      double bull_sl = current_low;
      double extended_sl = FindNextExtremeCandle("bull", bull_sl);
      if(extended_sl > 0 && extended_sl < bull_entry) bull_sl = extended_sl;
      double box_range = bull_entry - bull_sl;
      double bull_tp = bull_entry + (box_range * InpTPMultiplier);
      double target_40pip = bull_entry + (InpPipTarget * pip_value);
      
      CreateRRBox("bull", bull_confirmed_type, bull_entry, bull_sl, bull_tp, target_40pip, false);
      
      SendSignalAlert("BULL CONFIRMED | " + bull_confirmed_type + " | SL=" + DoubleToString(bull_sl, _Digits) + " | Entry=" + DoubleToString(bull_entry, _Digits));
   }
   
   //=== STEP 12: Final Entry Signal ===
   // Record setup bars
   if(bear_base_valid && (final_entry_bear_setup_bar < 0 || (current_bar - final_entry_bear_setup_bar) > 5))
   {
      final_entry_bear_setup_bar = current_bar;
      final_entry_bear_pattern = bear_base_type;
   }
   if(bear_intra_est_valid || bear_intra_em_valid || bear_intra_lv_valid || bear_intra_neg_valid || bear_zone_valid)
   {
      if(final_entry_bear_setup_bar < 0 || (current_bar - final_entry_bear_setup_bar) > 5)
      {
         final_entry_bear_setup_bar = current_bar;
         // Build pattern
         string parts = "";
         if(bear_zone_valid) parts = "ZONE";
         if(bear_intra_est_valid) parts += (parts != "" ? "+" : "") + "EST";
         if(bear_intra_em_valid) parts += (parts != "" ? "+" : "") + "EM";
         if(bear_intra_lv_valid) parts += (parts != "" ? "+" : "") + "LV";
         if(bear_intra_neg_valid && !bear_zone_valid) parts += (parts != "" ? "+" : "") + "NEG";
         final_entry_bear_pattern = "INTRA+" + parts + (bear_base_type != "" ? " [" + bear_base_type + "]" : "");
      }
   }
   
   if(bull_base_valid && (final_entry_bull_setup_bar < 0 || (current_bar - final_entry_bull_setup_bar) > 5))
   {
      final_entry_bull_setup_bar = current_bar;
      final_entry_bull_pattern = bull_base_type;
   }
   if(bull_intra_est_valid || bull_intra_em_valid || bull_intra_lv_valid || bull_intra_neg_valid || bull_zone_valid)
   {
      if(final_entry_bull_setup_bar < 0 || (current_bar - final_entry_bull_setup_bar) > 5)
      {
         final_entry_bull_setup_bar = current_bar;
         string parts = "";
         if(bull_zone_valid) parts = "ZONE";
         if(bull_intra_est_valid) parts += (parts != "" ? "+" : "") + "EST";
         if(bull_intra_em_valid) parts += (parts != "" ? "+" : "") + "EM";
         if(bull_intra_lv_valid) parts += (parts != "" ? "+" : "") + "LV";
         if(bull_intra_neg_valid && !bull_zone_valid) parts += (parts != "" ? "+" : "") + "NEG";
         final_entry_bull_pattern = "INTRA+" + parts + (bull_base_type != "" ? " [" + bull_base_type + "]" : "");
      }
   }
   
   // Check LAOL breaks for Final Entry trigger
   double bear_laol_broken_level = 0;
   double bull_laol_broken_level = 0;
   bool bear_laol_found = GetBrokenLaolRecent(bear_laol_lines, bear_laol_count, InpFinalEntryMultiLaol, bear_laol_broken_level);
   bool bull_laol_found = GetBrokenLaolRecent(bull_laol_lines, bull_laol_count, InpFinalEntryMultiLaol, bull_laol_broken_level);
   
   // Check scalp FU retest
   bool scalp_bear_fu_retest = false;
   bool scalp_bull_fu_retest = false;
   for(int i = SCALP_MIN_IDX; i <= SCALP_MAX_IDX; i++)
   {
      for(int bx_idx = 0; bx_idx < tf_boxes_count[i]; bx_idx++)
      {
         if(tf_boxes[i][bx_idx].has_been_retested && tf_boxes[i][bx_idx].state != STATE_FORMING)
         {
            if(tf_boxes[i][bx_idx].direction == "bear" && 
               (StringFind(tf_boxes[i][bx_idx].pattern_text, "FU") >= 0 || StringFind(tf_boxes[i][bx_idx].pattern_text, "SN") >= 0))
               scalp_bear_fu_retest = true;
            if(tf_boxes[i][bx_idx].direction == "bull" && 
               (StringFind(tf_boxes[i][bx_idx].pattern_text, "FU") >= 0 || StringFind(tf_boxes[i][bx_idx].pattern_text, "SN") >= 0))
               scalp_bull_fu_retest = true;
         }
      }
   }
   
   // Final entry conditions
   bool bear_setup_within_window = (final_entry_bear_setup_bar >= 0 && (current_bar - final_entry_bear_setup_bar) <= 10);
   bool bull_setup_within_window = (final_entry_bull_setup_bar >= 0 && (current_bar - final_entry_bull_setup_bar) <= 10);
   
   bool bear_has_intra_final = (InpShowFinalIntraEst && StringFind(final_entry_bear_pattern, "EST") >= 0) ||
                               (InpShowFinalIntraEM && StringFind(final_entry_bear_pattern, "EM") >= 0) ||
                               (InpShowFinalIntraLV && StringFind(final_entry_bear_pattern, "LV") >= 0) ||
                               (InpShowFinalIntraNeg && (StringFind(final_entry_bear_pattern, "NEG") >= 0 || StringFind(final_entry_bear_pattern, "ZONE") >= 0));
   
   bool final_entry_bear_base_sig = InpShowFinalEntry && InpShowFinalS1S4 && bear_setup_within_window && 
                                    StringFind(final_entry_bear_pattern, "S") >= 0 && !bear_has_intra_final && 
                                    bear_laol_found && scalp_bear_fu_retest && scalp_lv_dir == "bear" && !scalp_lv_broken;
   
   bool final_entry_bear_intra_est_sig = InpShowFinalEntry && InpShowFinalIntraEst && bear_setup_within_window && 
                                          StringFind(final_entry_bear_pattern, "EST") >= 0 && 
                                          bear_laol_found && scalp_bear_fu_retest && scalp_lv_dir == "bear" && !scalp_lv_broken;
   
   bool final_entry_bear_intra_em_sig = InpShowFinalEntry && InpShowFinalIntraEM && bear_setup_within_window && 
                                         StringFind(final_entry_bear_pattern, "EM") >= 0 && 
                                         bear_laol_found && scalp_bear_fu_retest && scalp_lv_dir == "bear" && !scalp_lv_broken;
   
   bool final_entry_bear_intra_neg_sig = InpShowFinalEntry && InpShowFinalIntraNeg && bear_setup_within_window && 
                                          (StringFind(final_entry_bear_pattern, "NEG") >= 0 || StringFind(final_entry_bear_pattern, "ZONE") >= 0) && 
                                          bear_laol_found && scalp_bear_fu_retest && scalp_lv_dir == "bear" && !scalp_lv_broken;
   
   bool final_entry_bear = final_entry_bear_base_sig || final_entry_bear_intra_est_sig || 
                           final_entry_bear_intra_em_sig || final_entry_bear_intra_neg_sig;
   
   bool bull_has_intra_final = (InpShowFinalIntraEst && StringFind(final_entry_bull_pattern, "EST") >= 0) ||
                               (InpShowFinalIntraEM && StringFind(final_entry_bull_pattern, "EM") >= 0) ||
                               (InpShowFinalIntraLV && StringFind(final_entry_bull_pattern, "LV") >= 0) ||
                               (InpShowFinalIntraNeg && (StringFind(final_entry_bull_pattern, "NEG") >= 0 || StringFind(final_entry_bull_pattern, "ZONE") >= 0));
   
   bool final_entry_bull_base_sig = InpShowFinalEntry && InpShowFinalS1S4 && bull_setup_within_window && 
                                    StringFind(final_entry_bull_pattern, "S") >= 0 && !bull_has_intra_final && 
                                    bull_laol_found && scalp_bull_fu_retest && scalp_lv_dir == "bull" && !scalp_lv_broken;
   
   bool final_entry_bull_intra_est_sig = InpShowFinalEntry && InpShowFinalIntraEst && bull_setup_within_window && 
                                          StringFind(final_entry_bull_pattern, "EST") >= 0 && 
                                          bull_laol_found && scalp_bull_fu_retest && scalp_lv_dir == "bull" && !scalp_lv_broken;
   
   bool final_entry_bull_intra_em_sig = InpShowFinalEntry && InpShowFinalIntraEM && bull_setup_within_window && 
                                         StringFind(final_entry_bull_pattern, "EM") >= 0 && 
                                         bull_laol_found && scalp_bull_fu_retest && scalp_lv_dir == "bull" && !scalp_lv_broken;
   
   bool final_entry_bull_intra_neg_sig = InpShowFinalEntry && InpShowFinalIntraNeg && bull_setup_within_window && 
                                          (StringFind(final_entry_bull_pattern, "NEG") >= 0 || StringFind(final_entry_bull_pattern, "ZONE") >= 0) && 
                                          bull_laol_found && scalp_bull_fu_retest && scalp_lv_dir == "bull" && !scalp_lv_broken;
   
   bool final_entry_bull = final_entry_bull_base_sig || final_entry_bull_intra_est_sig || 
                           final_entry_bull_intra_em_sig || final_entry_bull_intra_neg_sig;
   
   // Generate FINAL ENTRY signals
   if(final_entry_bear)
   {
      CleanFormingRR("bear");
      
      double bear_entry = MathMax(current_open, current_close);
      double bear_sl = current_high;
      double extended_sl = FindNextExtremeCandle("bear", bear_sl);
      if(extended_sl > 0 && extended_sl > bear_entry) bear_sl = extended_sl;
      double box_range = bear_sl - bear_entry;
      double bear_tp = bear_entry - (box_range * InpTPMultiplier);
      double target_40pip = bear_entry - (InpPipTarget * pip_value);
      
      string label = "FINAL " + final_entry_bear_pattern;
      CreateRRBox("bear", label, bear_entry, bear_sl, bear_tp, target_40pip, false);
      
      SendSignalAlert("FINAL ENTRY BEAR | " + final_entry_bear_pattern + " | SL=" + DoubleToString(bear_sl, _Digits) + " | Entry=" + DoubleToString(bear_entry, _Digits));
   }
   
   if(final_entry_bull)
   {
      CleanFormingRR("bull");
      
      double bull_entry = MathMin(current_open, current_close);
      double bull_sl = current_low;
      double extended_sl = FindNextExtremeCandle("bull", bull_sl);
      if(extended_sl > 0 && extended_sl < bull_entry) bull_sl = extended_sl;
      double box_range = bull_entry - bull_sl;
      double bull_tp = bull_entry + (box_range * InpTPMultiplier);
      double target_40pip = bull_entry + (InpPipTarget * pip_value);
      
      string label = "FINAL " + final_entry_bull_pattern;
      CreateRRBox("bull", label, bull_entry, bull_sl, bull_tp, target_40pip, false);
      
      SendSignalAlert("FINAL ENTRY BULL | " + final_entry_bull_pattern + " | SL=" + DoubleToString(bull_sl, _Digits) + " | Entry=" + DoubleToString(bull_entry, _Digits));
   }
   
   //=== STEP 13: Check RR box SL hits ===
   CheckRRBoxes();
   
   //=== STEP 14: Reset pattern arrays for next bar ===
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
   
   //=== STEP 15: Update comment on chart ===
   string comment_text = "=== STX Edge ===\n";
   comment_text += "Entry LV: " + entry_lv_text + " [" + entry_lv_dir + "]\n";
   comment_text += "Scalp LV: " + scalp_lv_text + " [" + scalp_lv_dir + "]\n";
   comment_text += "Intra LV: " + intra_lv_text + " [" + intra_lv_dir + "]\n";
   
   if(bear_base_valid || bear_has_any_intra)
   {
      comment_text += "BEAR Setup: ";
      if(bear_zone_forming || bear_zone_confirmed) comment_text += "INTRA+ZONE [" + bear_base_type + "]";
      else if(bear_intra_neg_forming || bear_intra_neg_confirmed) comment_text += "INTRA+NEG [" + bear_base_type + "]";
      else if(bear_intra_em_forming_sig || bear_intra_em_confirmed) comment_text += "INTRA+EM [" + bear_base_type + "]";
      else if(bear_intra_est_forming || bear_intra_est_confirmed) comment_text += "INTRA+EST [" + bear_base_type + "]";
      else comment_text += bear_base_type;
      comment_text += (m1_conf ? " [CONFIRMED]" : " [FORMING]") + "\n";
   }
   
   if(bull_base_valid || bull_has_any_intra)
   {
      comment_text += "BULL Setup: ";
      if(bull_zone_forming || bull_zone_confirmed) comment_text += "INTRA+ZONE [" + bull_base_type + "]";
      else if(bull_intra_neg_forming || bull_intra_neg_confirmed) comment_text += "INTRA+NEG [" + bull_base_type + "]";
      else if(bull_intra_em_forming_sig || bull_intra_em_confirmed) comment_text += "INTRA+EM [" + bull_base_type + "]";
      else if(bull_intra_est_forming || bull_intra_est_confirmed) comment_text += "INTRA+EST [" + bull_base_type + "]";
      else comment_text += bull_base_type;
      comment_text += (m1_conf ? " [CONFIRMED]" : " [FORMING]") + "\n";
   }
   
   if(intra_bear_negating)
      comment_text += "INTRA NEG: " + intra_bear_negating_pattern + "\n";
   if(intra_bull_negating)
      comment_text += "INTRA NEG: " + intra_bull_negating_pattern + "\n";
   
   if(final_entry_bear)
      comment_text += "*** FINAL ENTRY BEAR ***\n";
   if(final_entry_bull)
      comment_text += "*** FINAL ENTRY BULL ***\n";
   
   Comment(comment_text);
   
   return(rates_total);
}
//+------------------------------------------------------------------+
