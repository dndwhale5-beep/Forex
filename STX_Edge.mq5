//+------------------------------------------------------------------+
//|                                                    STX_Edge.mq5  |
//|                                          Copyright 2024, STX Edge|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "STX Edge"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input bool   InpSoftStart            = false;  // Soft Start
input int    InpTPMultiplier         = 8;      // TP Multiplier
input int    InpSetupLookback        = 5;      // Setup Lookback
input double InpPipTarget            = 40.0;   // Pip Target
input int    InpLaolDeleteDelay      = 2;      // LAOL Delete Delay
input bool   InpShowFinalEntry       = true;   // Show Final Entry
input bool   InpShowFinalS1S4        = true;   // Show Final S1-S4
input bool   InpShowFinalIntraEst    = true;   // Show Final Intra Est
input bool   InpShowFinalIntraEM     = true;   // Show Final Intra EM
input bool   InpShowFinalIntraLV     = false;  // Show Final Intra LV
input bool   InpShowFinalIntraNeg    = true;   // Show Final Intra Neg
input bool   InpFinalEntryMultiLaol  = false;  // Final Entry Multi LAOL
input bool   InpShowIntraEstRetest   = true;   // Show Intra Est Retest
input bool   InpShowIntraEMForming   = true;   // Show Intra EM Forming
input bool   InpShowIntraLVAligned   = false;  // Show Intra LV Aligned
input bool   InpShowIntraNegation    = true;   // Show Intra Negation
input bool   InpShowHCSBoxes         = true;   // Show HCS Boxes
input bool   InpShowSetupsS1S4       = true;   // Show Setups S1-S4

//+------------------------------------------------------------------+
//| Constants                                                         |
//+------------------------------------------------------------------+
#define TF_COUNT        25
#define ENTRY_MIN_IDX   0
#define ENTRY_MAX_IDX   4
#define SCALP_MIN_IDX   5
#define SCALP_MAX_IDX   15
#define INTRA_MIN_IDX   16
#define INTRA_MAX_IDX   24
#define MAX_BOXES       100
#define MAX_LAOL        50
#define MAX_HCS         20
#define MAX_RR          20

//+------------------------------------------------------------------+
//| Timeframe Minutes Array                                           |
//+------------------------------------------------------------------+
const int TF_MINUTES[TF_COUNT] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,20,30,35,40,45,50,55,60,90,100};

//+------------------------------------------------------------------+
//| GetTimeframe - Map minutes to ENUM_TIMEFRAMES                     |
//| Non-standard timeframes mapped to nearest available:              |
//| M7->M6, M8->M6, M9->M10, M11->M10, M13->M12, M14->M15,         |
//| M35->M30, M40->M30, M45->H1, M50->H1, M55->H1, M90->H1,        |
//| M100->H2                                                          |
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
      case 7:   return PERIOD_M6;
      case 8:   return PERIOD_M6;
      case 9:   return PERIOD_M10;
      case 10:  return PERIOD_M10;
      case 11:  return PERIOD_M10;
      case 12:  return PERIOD_M12;
      case 13:  return PERIOD_M12;
      case 14:  return PERIOD_M15;
      case 15:  return PERIOD_M15;
      case 20:  return PERIOD_M20;
      case 30:  return PERIOD_M30;
      case 35:  return PERIOD_M30;
      case 40:  return PERIOD_M30;
      case 45:  return PERIOD_H1;
      case 50:  return PERIOD_H1;
      case 55:  return PERIOD_H1;
      case 60:  return PERIOD_H1;
      case 90:  return PERIOD_H1;
      case 100: return PERIOD_H2;
      default:  return PERIOD_M1;
     }
  }

//+------------------------------------------------------------------+
//| Timeframe Category Enumeration                                    |
//+------------------------------------------------------------------+
enum ENUM_TF_CATEGORY
  {
   CAT_ENTRY = 0,
   CAT_SCALP = 1,
   CAT_INTRA = 2,
   CAT_NONE  = 3
  };

//+------------------------------------------------------------------+
//| GetCategory - Determine category from timeframe index             |
//+------------------------------------------------------------------+
ENUM_TF_CATEGORY GetCategory(int tf_idx)
  {
   if(tf_idx >= ENTRY_MIN_IDX && tf_idx <= ENTRY_MAX_IDX)
      return CAT_ENTRY;
   if(tf_idx >= SCALP_MIN_IDX && tf_idx <= SCALP_MAX_IDX)
      return CAT_SCALP;
   if(tf_idx >= INTRA_MIN_IDX && tf_idx <= INTRA_MAX_IDX)
      return CAT_INTRA;
   return CAT_NONE;
  }

//+------------------------------------------------------------------+
//| GetCategoryStr - Get category string name                         |
//+------------------------------------------------------------------+
string GetCategoryStr(int tf_idx)
  {
   switch(GetCategory(tf_idx))
     {
      case CAT_ENTRY: return "Entry";
      case CAT_SCALP: return "Scalp";
      case CAT_INTRA: return "Intra";
      default:        return "None";
     }
  }

//+------------------------------------------------------------------+
//| Struct: SeqState                                                   |
//+------------------------------------------------------------------+
struct SeqState
  {
   int               step;
   double            level;
   double            body;
   datetime          start_time;

                     SeqState() : step(0), level(0.0), body(0.0), start_time(0) {}
  };

//+------------------------------------------------------------------+
//| Struct: TrackedBox                                                 |
//+------------------------------------------------------------------+
struct TrackedBox
  {
   string            direction;
   string            state;
   double            top_val;
   double            bottom_val;
   double            original_top;
   double            original_bottom;
   datetime          creation_time;
   datetime          protection_end_time;
   string            pattern_text;
   string            timeframe_str;
   string            obj_name;
   string            text_obj_name;
   bool              has_est_retest;
   string            retest_type;
   bool              protection_active;
   int               hcs_count;
   string            base_pattern;
   color             box_clr;
   color             border_clr;
   bool              has_been_retested;
   bool              is_intra;
   double            est_wick_high;
   double            est_wick_low;
   bool              completed_est_retest;
   bool              is_em_forming;
   bool              just_established;
   bool              used;

                     TrackedBox() : direction(""), state(""), top_val(0.0), bottom_val(0.0),
                        original_top(0.0), original_bottom(0.0), creation_time(0),
                        protection_end_time(0), pattern_text(""), timeframe_str(""),
                        obj_name(""), text_obj_name(""), has_est_retest(false),
                        retest_type(""), protection_active(false), hcs_count(0),
                        base_pattern(""), box_clr(clrNONE), border_clr(clrNONE),
                        has_been_retested(false), is_intra(false), est_wick_high(0.0),
                        est_wick_low(0.0), completed_est_retest(false),
                        is_em_forming(false), just_established(false), used(false) {}
  };

//+------------------------------------------------------------------+
//| Struct: LaolLineData                                               |
//+------------------------------------------------------------------+
struct LaolLineData
  {
   string            line_obj_name;
   string            label_obj_name;
   double            level;
   string            tf_labels;
   int               creation_bar;
   bool              is_bear;
   bool              is_broken;
   int               break_bar;
   int               tf_count;
   bool              has_entry;
   bool              has_scalp;
   bool              has_intra;
   bool              used;

                     LaolLineData() : line_obj_name(""), label_obj_name(""), level(0.0),
                        tf_labels(""), creation_bar(0), is_bear(false), is_broken(false),
                        break_bar(0), tf_count(0), has_entry(false), has_scalp(false),
                        has_intra(false), used(false) {}
  };

//+------------------------------------------------------------------+
//| Struct: LastValidInfo                                              |
//+------------------------------------------------------------------+
struct LastValidInfo
  {
   string            pattern_text;
   string            original_text;
   double            level;
   datetime          est_time;
   string            direction;
   bool              is_broken;

                     LastValidInfo() : pattern_text(""), original_text(""), level(0.0),
                        est_time(0), direction(""), is_broken(false) {}
  };

//+------------------------------------------------------------------+
//| Struct: HcsBoxData                                                 |
//+------------------------------------------------------------------+
struct HcsBoxData
  {
   string            obj_name;
   string            text_obj_name;
   double            top_val;
   double            bottom_val;
   int               creation_bar;
   string            tf_label;
   string            direction;
   bool              is_broken;
   bool              used;

                     HcsBoxData() : obj_name(""), text_obj_name(""), top_val(0.0),
                        bottom_val(0.0), creation_bar(0), tf_label(""), direction(""),
                        is_broken(false), used(false) {}
  };

//+------------------------------------------------------------------+
//| Struct: RrBoxSet                                                   |
//+------------------------------------------------------------------+
struct RrBoxSet
  {
   string            sl_obj_name;
   string            tp_obj_name;
   string            pip_obj_name;
   string            direction;
   double            sl_level;
   int               creation_bar;
   bool              used;

                     RrBoxSet() : sl_obj_name(""), tp_obj_name(""), pip_obj_name(""),
                        direction(""), sl_level(0.0), creation_bar(0), used(false) {}
  };

//+------------------------------------------------------------------+
//| Color Constants (ARGB format for MT5 ObjectSetInteger)             |
//| Alpha: 0=opaque, 255=fully transparent                            |
//| Using ColorToARGB(color, alpha) where alpha 0-255                 |
//| 95% transparency = alpha 12, 90% = alpha 25, 80% = alpha 51      |
//| 70% = alpha 77, 50% = alpha 128, 30% = alpha 178                 |
//+------------------------------------------------------------------+
const uint entry_box_color    = ColorToARGB(clrBlue, 12);        // Blue 95% transparent
const uint entry_border_color = ColorToARGB(clrBlue, 128);       // Blue 50% transparent
const uint scalp_box_color    = ColorToARGB(clrGreen, 25);       // Green 90% transparent
const uint scalp_border_color = ColorToARGB(clrGreen, 128);      // Green 50% transparent
const uint intra_box_color    = ColorToARGB(clrRed, 12);         // Red 95% transparent
const uint intra_border_color = ColorToARGB(clrRed, 128);        // Red 50% transparent
const uint hcs_bear_bg        = ColorToARGB(clrOrange, 51);      // Orange 80% transparent
const uint hcs_bear_border    = ColorToARGB(clrOrange, 178);     // Orange 30% transparent
const uint hcs_bull_bg        = ColorToARGB(C'33,150,243', 51);  // #2196F3 80% transparent
const uint hcs_bull_border    = ColorToARGB(C'33,150,243', 178); // #2196F3 30% transparent
const uint rr_sl_color        = ColorToARGB(clrRed, 77);         // Red 70% transparent
const uint rr_tp_color        = ColorToARGB(clrGreen, 77);       // Green 70% transparent

//+------------------------------------------------------------------+
//| Global State Arrays and Variables                                  |
//+------------------------------------------------------------------+

//--- Timeframe label and category string arrays
string TF_LABELS[TF_COUNT];
string TF_CATEGORIES[TF_COUNT];

//--- Pattern detection arrays (bool[TF_COUNT])
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

//--- Timeframe data arrays
double   arr_tf_h[TF_COUNT];
double   arr_tf_l[TF_COUNT];
double   arr_tf_bt[TF_COUNT];
double   arr_tf_bb[TF_COUNT];
datetime arr_tf_t[TF_COUNT];
bool     arr_tf_conf[TF_COUNT];

//--- Sequence state arrays
SeqState arr_bear_seq[TF_COUNT];
SeqState arr_bull_seq[TF_COUNT];

//--- HCS detection arrays
bool     arr_bear_hcs[TF_COUNT];
bool     arr_bull_hcs[TF_COUNT];
bool     arr_bear_hcs_forming[TF_COUNT];
bool     arr_bull_hcs_forming[TF_COUNT];
datetime arr_last_bear_hcs_time[TF_COUNT];
datetime arr_last_bull_hcs_time[TF_COUNT];
bool     arr_bear_hcs_broken[TF_COUNT];
bool     arr_bull_hcs_broken[TF_COUNT];
bool     arr_bear_hcs_retesting[TF_COUNT];
bool     arr_bull_hcs_retesting[TF_COUNT];

//--- Third step tracking arrays
int      arr_bear_third_step[TF_COUNT];
double   arr_bear_third_ref_h[TF_COUNT];
double   arr_bear_third_ref_l[TF_COUNT];
datetime arr_bear_third_ref_time[TF_COUNT];
int      arr_bull_third_step[TF_COUNT];
double   arr_bull_third_ref_h[TF_COUNT];
double   arr_bull_third_ref_l[TF_COUNT];
datetime arr_bull_third_ref_time[TF_COUNT];

//--- LAOL step tracking arrays
int      arr_bear_laol_step[TF_COUNT];
double   arr_bear_laol_ref_h[TF_COUNT];
double   arr_bear_laol_ref_l[TF_COUNT];
datetime arr_bear_laol_ref_time[TF_COUNT];
int      arr_bull_laol_step[TF_COUNT];
double   arr_bull_laol_ref_h[TF_COUNT];
double   arr_bull_laol_ref_l[TF_COUNT];
datetime arr_bull_laol_ref_time[TF_COUNT];

//--- Retesting arrays
bool   arr_bear_retesting[TF_COUNT];
bool   arr_bull_retesting[TF_COUNT];
bool   arr_bear_est_retest[TF_COUNT];
bool   arr_bull_est_retest[TF_COUNT];
bool   arr_bear_est_retest_VALID[TF_COUNT];
bool   arr_bull_est_retest_VALID[TF_COUNT];
bool   arr_bear_est_retest_VALID_prev[TF_COUNT];
bool   arr_bull_est_retest_VALID_prev[TF_COUNT];
string arr_bear_retest_pattern[TF_COUNT];
string arr_bull_retest_pattern[TF_COUNT];
double arr_bear_retest_level[TF_COUNT];
double arr_bull_retest_level[TF_COUNT];

//--- LAOL candle arrays
bool arr_laol_candle_bear[TF_COUNT];
bool arr_laol_candle_bull[TF_COUNT];

//+------------------------------------------------------------------+
//| TrackedBox arrays for all 25 timeframes                           |
//+------------------------------------------------------------------+
TrackedBox tf1_boxes[MAX_BOXES];  int tf1_boxes_count  = 0;
TrackedBox tf2_boxes[MAX_BOXES];  int tf2_boxes_count  = 0;
TrackedBox tf3_boxes[MAX_BOXES];  int tf3_boxes_count  = 0;
TrackedBox tf4_boxes[MAX_BOXES];  int tf4_boxes_count  = 0;
TrackedBox tf5_boxes[MAX_BOXES];  int tf5_boxes_count  = 0;
TrackedBox tf6_boxes[MAX_BOXES];  int tf6_boxes_count  = 0;
TrackedBox tf7_boxes[MAX_BOXES];  int tf7_boxes_count  = 0;
TrackedBox tf8_boxes[MAX_BOXES];  int tf8_boxes_count  = 0;
TrackedBox tf9_boxes[MAX_BOXES];  int tf9_boxes_count  = 0;
TrackedBox tf10_boxes[MAX_BOXES]; int tf10_boxes_count = 0;
TrackedBox tf11_boxes[MAX_BOXES]; int tf11_boxes_count = 0;
TrackedBox tf12_boxes[MAX_BOXES]; int tf12_boxes_count = 0;
TrackedBox tf13_boxes[MAX_BOXES]; int tf13_boxes_count = 0;
TrackedBox tf14_boxes[MAX_BOXES]; int tf14_boxes_count = 0;
TrackedBox tf15_boxes[MAX_BOXES]; int tf15_boxes_count = 0;
TrackedBox tf16_boxes[MAX_BOXES]; int tf16_boxes_count = 0;
TrackedBox tf17_boxes[MAX_BOXES]; int tf17_boxes_count = 0;
TrackedBox tf18_boxes[MAX_BOXES]; int tf18_boxes_count = 0;
TrackedBox tf19_boxes[MAX_BOXES]; int tf19_boxes_count = 0;
TrackedBox tf20_boxes[MAX_BOXES]; int tf20_boxes_count = 0;
TrackedBox tf21_boxes[MAX_BOXES]; int tf21_boxes_count = 0;
TrackedBox tf22_boxes[MAX_BOXES]; int tf22_boxes_count = 0;
TrackedBox tf23_boxes[MAX_BOXES]; int tf23_boxes_count = 0;
TrackedBox tf24_boxes[MAX_BOXES]; int tf24_boxes_count = 0;
TrackedBox tf25_boxes[MAX_BOXES]; int tf25_boxes_count = 0;

//+------------------------------------------------------------------+
//| LaolLineData dynamic arrays (with count)                          |
//+------------------------------------------------------------------+
LaolLineData bear_laol_lines[MAX_LAOL];        int bear_laol_lines_count        = 0;
LaolLineData bull_laol_lines[MAX_LAOL];        int bull_laol_lines_count        = 0;
LaolLineData bear_intra_laol_lines[MAX_LAOL];  int bear_intra_laol_lines_count  = 0;
LaolLineData bull_intra_laol_lines[MAX_LAOL];  int bull_intra_laol_lines_count  = 0;
LaolLineData bear_scalp_laol_lines[MAX_LAOL];  int bear_scalp_laol_lines_count  = 0;
LaolLineData bull_scalp_laol_lines[MAX_LAOL];  int bull_scalp_laol_lines_count  = 0;

//+------------------------------------------------------------------+
//| HcsBoxData dynamic arrays (with count)                            |
//+------------------------------------------------------------------+
HcsBoxData hcs_boxes_bear[MAX_HCS]; int hcs_boxes_bear_count = 0;
HcsBoxData hcs_boxes_bull[MAX_HCS]; int hcs_boxes_bull_count = 0;

//+------------------------------------------------------------------+
//| RrBoxSet dynamic arrays (with count)                              |
//+------------------------------------------------------------------+
RrBoxSet rr_boxes_bear[MAX_RR]; int rr_boxes_bear_count = 0;
RrBoxSet rr_boxes_bull[MAX_RR]; int rr_boxes_bull_count = 0;

//+------------------------------------------------------------------+
//| LastValidInfo instances                                            |
//+------------------------------------------------------------------+
LastValidInfo entry_bear_lv;
LastValidInfo entry_bull_lv;
LastValidInfo scalp_bear_lv;
LastValidInfo scalp_bull_lv;
LastValidInfo intra_bear_lv;
LastValidInfo intra_bull_lv;

//+------------------------------------------------------------------+
//| Forming/display state variables                                    |
//+------------------------------------------------------------------+
//--- Bear forming RR object tracking
string bear_forming_rr_sl_name  = "";
string bear_forming_rr_tp_name  = "";
string bear_forming_rr_pip_name = "";
int    bear_forming_rr_bar      = -1;

//--- Bull forming RR object tracking
string bull_forming_rr_sl_name  = "";
string bull_forming_rr_tp_name  = "";
string bull_forming_rr_pip_name = "";
int    bull_forming_rr_bar      = -1;

//--- Final entry setup tracking
int    final_entry_bear_setup_bar = -1;
int    final_entry_bull_setup_bar = -1;
string final_entry_bear_pattern   = "";
string final_entry_bull_pattern   = "";

//--- Last forming/confirmed bar tracking
int last_bear_forming_bar   = -1;
int last_bear_confirmed_bar = -1;
int last_bull_forming_bar   = -1;
int last_bull_confirmed_bar = -1;

//--- Intra negation state
bool   intra_bear_negating         = false;
bool   intra_bull_negating         = false;
string intra_bear_negating_pattern = "";
string intra_bull_negating_pattern = "";

//+------------------------------------------------------------------+
//| LAOL break time tracking                                          |
//+------------------------------------------------------------------+
datetime last_bear_laol_break_time       = 0;
datetime last_bull_laol_break_time       = 0;
string   last_bear_laol_tf               = "";
string   last_bull_laol_tf               = "";
datetime last_bear_intra_laol_break_time = 0;
datetime last_bull_intra_laol_break_time = 0;
string   last_bear_intra_laol_tf         = "";
string   last_bull_intra_laol_tf         = "";
datetime last_bear_scalp_laol_break_time = 0;
datetime last_bull_scalp_laol_break_time = 0;
string   last_bear_scalp_laol_tf         = "";
string   last_bull_scalp_laol_tf         = "";

//+------------------------------------------------------------------+
//| XLAOL arrays (for LAOL lines drawn inside boxes)                  |
//+------------------------------------------------------------------+
#define MAX_XLAOL 100
string xlaol_line_names[MAX_XLAOL];
string xlaol_label_names[MAX_XLAOL];
double xlaol_levels[MAX_XLAOL];
bool   xlaol_bear[MAX_XLAOL];
string xlaol_cat[MAX_XLAOL];
int    xlaol_off[MAX_XLAOL];
int    xlaol_count = 0;

//+------------------------------------------------------------------+
//| Display text arrays (forming/retesting/negation)                  |
//+------------------------------------------------------------------+
#define MAX_DISPLAY_TEXT 200
string entry_forming[MAX_DISPLAY_TEXT];      int entry_forming_count      = 0;
string entry_retesting[MAX_DISPLAY_TEXT];    int entry_retesting_count    = 0;
string scalp_forming[MAX_DISPLAY_TEXT];      int scalp_forming_count      = 0;
string scalp_retesting[MAX_DISPLAY_TEXT];    int scalp_retesting_count    = 0;
string intra_forming[MAX_DISPLAY_TEXT];      int intra_forming_count      = 0;
string intra_retesting[MAX_DISPLAY_TEXT];    int intra_retesting_count    = 0;
string intra_negation[MAX_DISPLAY_TEXT];     int intra_negation_count     = 0;

//+------------------------------------------------------------------+
//| Forming type tracking                                             |
//+------------------------------------------------------------------+
string bear_forming_type      = "";
string bear_forming_type_prev = "";
string bull_forming_type      = "";
string bull_forming_type_prev = "";

//+------------------------------------------------------------------+
//| Global utility variables                                          |
//+------------------------------------------------------------------+
int      g_obj_counter = 0;          // For unique object names
int      g_bar_index   = 0;          // For bar counting
datetime g_prev_tf_time[TF_COUNT];   // For bar confirmation tracking
double   g_pip_value   = 0.0;        // Pip value (syminfo.mintick * 10 equivalent)

//+------------------------------------------------------------------+
//|                                                                    |
//|                 HELPER / UTILITY FUNCTIONS                         |
//|                                                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| GenerateObjName - Create unique object name with prefix           |
//+------------------------------------------------------------------+
string GenerateObjName(string prefix)
  {
   g_obj_counter++;
   return prefix + "_" + IntegerToString(g_obj_counter);
  }

//+------------------------------------------------------------------+
//| FormatTFLabel - Convert minutes to display label (e.g. "5m","1H") |
//+------------------------------------------------------------------+
string FormatTFLabel(int minutes)
  {
   if(minutes >= 60 && minutes % 60 == 0)
      return IntegerToString(minutes / 60) + "H";
   else
      return IntegerToString(minutes) + "m";
  }

//+------------------------------------------------------------------+
//| IsEntry - Check if timeframe is entry category (1-5 minutes)      |
//+------------------------------------------------------------------+
bool IsEntry(int minutes)
  {
   return (minutes >= 1 && minutes <= 5);
  }

//+------------------------------------------------------------------+
//| GetFullCategory - Return category string based on minutes         |
//+------------------------------------------------------------------+
string GetFullCategory(int minutes)
  {
   if(minutes >= 1 && minutes <= 5)
      return "ENTRY";
   else if(minutes >= 6 && minutes <= 20)
      return "SCALP";
   else if(minutes >= 30 && minutes <= 120)
      return "INTRA";
   else
      return "NONE";
  }

//+------------------------------------------------------------------+
//| PatternStr - Build pattern string from booleans                   |
//| Matches f_pattern_str in Pine Script exactly                      |
//+------------------------------------------------------------------+
string PatternStr(bool is_bear, bool third, bool first, bool laol, bool sn, bool sn_dbl, bool fu, bool tbe, bool hcs, bool hcs_forming)
  {
   string result = "";

   if(third)
      result = "X3 Third";

   if(first)
     {
      if(result == "")
         result = "X3 First";
      else
         result = result + " + X3 First";
     }

   if(laol)
     {
      if(result == "")
         result = "LAOL Neg";
      else
         result = result + " + LAOL Neg";
     }

   if(sn)
     {
      string sn_txt = sn_dbl ? "SN [EM]" : "SN";
      if(result == "")
         result = sn_txt;
      else
         result = result + " + " + sn_txt;
     }

   if(fu)
     {
      string fu_txt = tbe ? "FU [TBE]" : "FU";
      if(result == "")
         result = fu_txt;
      else
         result = result + " + " + fu_txt;
     }

   if(hcs)
     {
      if(result == "")
         result = "[HCS]";
      else
         result = result + " + [HCS]";
     }
   else if(hcs_forming)
     {
      if(result == "")
         result = "[HCS]";
      else
         result = result + " + [HCS]";
     }

   if(result != "")
      return (is_bear ? "Bear " : "Bull ") + result;
   else
      return "";
  }

//+------------------------------------------------------------------+
//| IsFuPattern - Check if pattern is FU-type (FU or SN without EM)  |
//| Matches f_is_fu_pattern in Pine Script                            |
//+------------------------------------------------------------------+
bool IsFuPattern(string pattern)
  {
   if(pattern == "")
      return false;

   bool has_fu = (StringFind(pattern, "FU") >= 0);
   bool has_sn = (StringFind(pattern, "SN") >= 0);
   bool has_em_modifier = (StringFind(pattern, "HCS") >= 0) ||
                          (StringFind(pattern, "Third") >= 0) ||
                          (StringFind(pattern, "First") >= 0) ||
                          (StringFind(pattern, "LAOL") >= 0) ||
                          (StringFind(pattern, "TBE") >= 0);

   return (has_fu || has_sn) && !has_em_modifier;
  }

//+------------------------------------------------------------------+
//| IsEmPattern - Check if pattern is EM-type                         |
//| Matches f_is_em_pattern in Pine Script                            |
//+------------------------------------------------------------------+
bool IsEmPattern(string pattern)
  {
   if(pattern == "")
      return false;

   return (StringFind(pattern, "HCS") >= 0) ||
          (StringFind(pattern, "Third") >= 0) ||
          (StringFind(pattern, "First") >= 0) ||
          (StringFind(pattern, "LAOL") >= 0) ||
          (StringFind(pattern, "TBE") >= 0) ||
          (StringFind(pattern, "[EM]") >= 0);
  }

//+------------------------------------------------------------------+
//| HasBothWicks - Check if candle has both upper and lower wicks     |
//+------------------------------------------------------------------+
bool HasBothWicks(double o, double h, double l, double c)
  {
   return (MathMax(o, c) < h) && (MathMin(o, c) > l);
  }

//+------------------------------------------------------------------+
//| IsInsideBar - Check if bar is inside the previous bar             |
//+------------------------------------------------------------------+
bool IsInsideBar(double p_h, double p_l, double p_h1, double p_l1)
  {
   return (p_h < p_h1) && (p_l > p_l1);
  }

//+------------------------------------------------------------------+
//| BullishIBConfirmation - Bullish inside bar confirmation           |
//+------------------------------------------------------------------+
bool BullishIBConfirmation(double p_o1, double p_h1, double p_l1, double p_c1)
  {
   return (MathMin(p_o1, p_c1) - p_l1) > (p_h1 - MathMax(p_o1, p_c1));
  }

//+------------------------------------------------------------------+
//| BearishIBConfirmation - Bearish inside bar confirmation           |
//+------------------------------------------------------------------+
bool BearishIBConfirmation(double p_o1, double p_h1, double p_l1, double p_c1)
  {
   return (p_h1 - MathMax(p_o1, p_c1)) > (MathMin(p_o1, p_c1) - p_l1);
  }

//+------------------------------------------------------------------+
//| CreateRectangleObj - Create rectangle on chart with all props     |
//+------------------------------------------------------------------+
void CreateRectangleObj(string name, datetime time1, double price1,
                        datetime time2, double price2, color clr_border,
                        color clr_fill, int border_style, int border_width,
                        bool fill, string text = "")
  {
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price1, time2, price2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr_border);
   ObjectSetInteger(0, name, OBJPROP_STYLE, border_style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, border_width);
   ObjectSetInteger(0, name, OBJPROP_FILL, fill);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

   if(fill)
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr_fill);

   if(text != "")
      ObjectSetString(0, name, OBJPROP_TEXT, text);
  }

//+------------------------------------------------------------------+
//| UpdateRectCoords - Update existing rectangle coordinates          |
//+------------------------------------------------------------------+
void UpdateRectCoords(string name, datetime time1, double price1,
                      datetime time2, double price2)
  {
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, time1);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, time2);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price2);
  }

//+------------------------------------------------------------------+
//| SetRectBorderStyle - Change rectangle border style and color      |
//+------------------------------------------------------------------+
void SetRectBorderStyle(string name, int style, color clr)
  {
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
  }

//+------------------------------------------------------------------+
//| CreateTrendLineObj - Create trend line on chart                   |
//+------------------------------------------------------------------+
void CreateTrendLineObj(string name, datetime time1, double price1,
                        datetime time2, double price2, color clr,
                        int style, int width)
  {
   ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//| CreateTextObj - Create text label at specific coordinates         |
//+------------------------------------------------------------------+
void CreateTextObj(string name, datetime time1, double price1,
                   string text, color clr, int font_size = 8)
  {
   ObjectCreate(0, name, OBJ_TEXT, 0, time1, price1);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//| DeleteObj - Delete a single object by name                        |
//+------------------------------------------------------------------+
void DeleteObj(string name)
  {
   if(name != "")
      ObjectDelete(0, name);
  }

//+------------------------------------------------------------------+
//| TimeAgoStr - Convert elapsed time to readable string              |
//| Matches f_time_ago in Pine Script                                 |
//+------------------------------------------------------------------+
string TimeAgoStr(datetime past_time)
  {
   if(past_time == 0)
      return "";

   long elapsed_sec = (long)(TimeCurrent() - past_time);
   long elapsed_min = elapsed_sec / 60;

   if(elapsed_min < 1)
      return " (<1m ago)";
   else if(elapsed_min < 60)
      return " (" + IntegerToString(elapsed_min) + "m ago)";
   else if(elapsed_min < 1440)
     {
      long hours = elapsed_min / 60;
      long mins  = elapsed_min % 60;
      if(mins > 0)
         return " (" + IntegerToString(hours) + "h" + IntegerToString(mins) + "m ago)";
      else
         return " (" + IntegerToString(hours) + "h ago)";
     }
   else
     {
      long days = elapsed_min / 1440;
      return " (" + IntegerToString(days) + "d ago)";
     }
  }

//+------------------------------------------------------------------+
//| PushUniqueStr - Add string to array only if not duplicate         |
//| Returns true if added, false if duplicate                         |
//+------------------------------------------------------------------+
bool PushUniqueStr(string &arr[], int &count, int max_size, string txt)
  {
   for(int i = 0; i < count; i++)
     {
      if(arr[i] == txt)
         return false;
     }
   if(count < max_size)
     {
      arr[count] = txt;
      count++;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| CheckBreak - Check if last valid level is broken                  |
//| Matches f_check_break in Pine Script                              |
//+------------------------------------------------------------------+
void CheckBreak(LastValidInfo &lv, double h, double l)
  {
   if(lv.original_text != "None" && lv.original_text != "" && lv.level != 0.0)
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
//| ResolveLastValid - Determine which last valid to display          |
//| Matches f_resolve_last_valid in Pine Script                       |
//+------------------------------------------------------------------+
void ResolveLastValid(LastValidInfo &bear_lv, LastValidInfo &bull_lv,
                      string &lv_text, string &lv_dir,
                      string &lv_orig_dir, bool &lv_broken)
  {
   lv_text     = "None";
   lv_dir      = "";
   lv_orig_dir = "";
   lv_broken   = false;

   if(bear_lv.est_time > 0 || bull_lv.est_time > 0)
     {
      if(bear_lv.est_time > bull_lv.est_time)
        {
         lv_text     = bear_lv.pattern_text + TimeAgoStr(bear_lv.est_time);
         lv_dir      = bear_lv.is_broken ? "bull" : "bear";
         lv_orig_dir = "bear";
         lv_broken   = bear_lv.is_broken;
        }
      else
        {
         lv_text     = bull_lv.pattern_text + TimeAgoStr(bull_lv.est_time);
         lv_dir      = bull_lv.is_broken ? "bear" : "bull";
         lv_orig_dir = "bull";
         lv_broken   = bull_lv.is_broken;
        }
     }
  }

//+------------------------------------------------------------------+
//| FindNextExtremeCandle - Find extreme candle beyond SL level       |
//| Matches f_find_next_extreme_candle in Pine Script                 |
//+------------------------------------------------------------------+
double FindNextExtremeCandle(string direction, double original_sl, int lookback = 500)
  {
   double extreme_level = 0.0;

   if(direction == "bear")
     {
      for(int i = 1; i <= lookback; i++)
        {
         if(iHigh(NULL, PERIOD_CURRENT, i) > original_sl)
           {
            extreme_level = iHigh(NULL, PERIOD_CURRENT, i);
            break;
           }
        }
     }
   else
     {
      for(int i = 1; i <= lookback; i++)
        {
         if(iLow(NULL, PERIOD_CURRENT, i) < original_sl)
           {
            extreme_level = iLow(NULL, PERIOD_CURRENT, i);
            break;
           }
        }
     }

   return extreme_level;
  }

//+------------------------------------------------------------------+
//| GetTFBoxesCount - Get the count for a specific TF box array       |
//+------------------------------------------------------------------+
int GetTFBoxesCount(int tf_idx)
  {
   switch(tf_idx)
     {
      case 0:  return tf1_boxes_count;
      case 1:  return tf2_boxes_count;
      case 2:  return tf3_boxes_count;
      case 3:  return tf4_boxes_count;
      case 4:  return tf5_boxes_count;
      case 5:  return tf6_boxes_count;
      case 6:  return tf7_boxes_count;
      case 7:  return tf8_boxes_count;
      case 8:  return tf9_boxes_count;
      case 9:  return tf10_boxes_count;
      case 10: return tf11_boxes_count;
      case 11: return tf12_boxes_count;
      case 12: return tf13_boxes_count;
      case 13: return tf14_boxes_count;
      case 14: return tf15_boxes_count;
      case 15: return tf16_boxes_count;
      case 16: return tf17_boxes_count;
      case 17: return tf18_boxes_count;
      case 18: return tf19_boxes_count;
      case 19: return tf20_boxes_count;
      case 20: return tf21_boxes_count;
      case 21: return tf22_boxes_count;
      case 22: return tf23_boxes_count;
      case 23: return tf24_boxes_count;
      case 24: return tf25_boxes_count;
      default: return 0;
     }
  }

//+------------------------------------------------------------------+
//| SetTFBoxesCount - Set the count for a specific TF box array       |
//+------------------------------------------------------------------+
void SetTFBoxesCount(int tf_idx, int value)
  {
   switch(tf_idx)
     {
      case 0:  tf1_boxes_count  = value; break;
      case 1:  tf2_boxes_count  = value; break;
      case 2:  tf3_boxes_count  = value; break;
      case 3:  tf4_boxes_count  = value; break;
      case 4:  tf5_boxes_count  = value; break;
      case 5:  tf6_boxes_count  = value; break;
      case 6:  tf7_boxes_count  = value; break;
      case 7:  tf8_boxes_count  = value; break;
      case 8:  tf9_boxes_count  = value; break;
      case 9:  tf10_boxes_count = value; break;
      case 10: tf11_boxes_count = value; break;
      case 11: tf12_boxes_count = value; break;
      case 12: tf13_boxes_count = value; break;
      case 13: tf14_boxes_count = value; break;
      case 14: tf15_boxes_count = value; break;
      case 15: tf16_boxes_count = value; break;
      case 16: tf17_boxes_count = value; break;
      case 17: tf18_boxes_count = value; break;
      case 18: tf19_boxes_count = value; break;
      case 19: tf20_boxes_count = value; break;
      case 20: tf21_boxes_count = value; break;
      case 21: tf22_boxes_count = value; break;
      case 22: tf23_boxes_count = value; break;
      case 23: tf24_boxes_count = value; break;
      case 24: tf25_boxes_count = value; break;
     }
  }

//+------------------------------------------------------------------+
//| GetTFBox - Get a TrackedBox by TF index and box index             |
//+------------------------------------------------------------------+
void GetTFBox(int tf_idx, int box_idx, TrackedBox &box)
  {
   switch(tf_idx)
     {
      case 0:  box = tf1_boxes[box_idx];  break;
      case 1:  box = tf2_boxes[box_idx];  break;
      case 2:  box = tf3_boxes[box_idx];  break;
      case 3:  box = tf4_boxes[box_idx];  break;
      case 4:  box = tf5_boxes[box_idx];  break;
      case 5:  box = tf6_boxes[box_idx];  break;
      case 6:  box = tf7_boxes[box_idx];  break;
      case 7:  box = tf8_boxes[box_idx];  break;
      case 8:  box = tf9_boxes[box_idx];  break;
      case 9:  box = tf10_boxes[box_idx]; break;
      case 10: box = tf11_boxes[box_idx]; break;
      case 11: box = tf12_boxes[box_idx]; break;
      case 12: box = tf13_boxes[box_idx]; break;
      case 13: box = tf14_boxes[box_idx]; break;
      case 14: box = tf15_boxes[box_idx]; break;
      case 15: box = tf16_boxes[box_idx]; break;
      case 16: box = tf17_boxes[box_idx]; break;
      case 17: box = tf18_boxes[box_idx]; break;
      case 18: box = tf19_boxes[box_idx]; break;
      case 19: box = tf20_boxes[box_idx]; break;
      case 20: box = tf21_boxes[box_idx]; break;
      case 21: box = tf22_boxes[box_idx]; break;
      case 22: box = tf23_boxes[box_idx]; break;
      case 23: box = tf24_boxes[box_idx]; break;
      case 24: box = tf25_boxes[box_idx]; break;
     }
  }

//+------------------------------------------------------------------+
//| SetTFBox - Set a TrackedBox by TF index and box index             |
//+------------------------------------------------------------------+
void SetTFBox(int tf_idx, int box_idx, TrackedBox &box)
  {
   switch(tf_idx)
     {
      case 0:  tf1_boxes[box_idx]  = box; break;
      case 1:  tf2_boxes[box_idx]  = box; break;
      case 2:  tf3_boxes[box_idx]  = box; break;
      case 3:  tf4_boxes[box_idx]  = box; break;
      case 4:  tf5_boxes[box_idx]  = box; break;
      case 5:  tf6_boxes[box_idx]  = box; break;
      case 6:  tf7_boxes[box_idx]  = box; break;
      case 7:  tf8_boxes[box_idx]  = box; break;
      case 8:  tf9_boxes[box_idx]  = box; break;
      case 9:  tf10_boxes[box_idx] = box; break;
      case 10: tf11_boxes[box_idx] = box; break;
      case 11: tf12_boxes[box_idx] = box; break;
      case 12: tf13_boxes[box_idx] = box; break;
      case 13: tf14_boxes[box_idx] = box; break;
      case 14: tf15_boxes[box_idx] = box; break;
      case 15: tf16_boxes[box_idx] = box; break;
      case 16: tf17_boxes[box_idx] = box; break;
      case 17: tf18_boxes[box_idx] = box; break;
      case 18: tf19_boxes[box_idx] = box; break;
      case 19: tf20_boxes[box_idx] = box; break;
      case 20: tf21_boxes[box_idx] = box; break;
      case 21: tf22_boxes[box_idx] = box; break;
      case 22: tf23_boxes[box_idx] = box; break;
      case 23: tf24_boxes[box_idx] = box; break;
      case 24: tf25_boxes[box_idx] = box; break;
     }
  }

//+------------------------------------------------------------------+
//| AddTFBox - Add a TrackedBox to the specified TF array             |
//| Returns the index of the new box, or -1 if full                   |
//+------------------------------------------------------------------+
int AddTFBox(int tf_idx, TrackedBox &box)
  {
   int count = GetTFBoxesCount(tf_idx);
   if(count >= MAX_BOXES)
      return -1;

   SetTFBox(tf_idx, count, box);
   SetTFBoxesCount(tf_idx, count + 1);
   return count;
  }

//+------------------------------------------------------------------+
//| RemoveTFBox - Remove TrackedBox at index, shift remaining down    |
//+------------------------------------------------------------------+
void RemoveTFBox(int tf_idx, int box_idx)
  {
   int count = GetTFBoxesCount(tf_idx);
   if(box_idx < 0 || box_idx >= count)
      return;

   TrackedBox temp;
   for(int i = box_idx; i < count - 1; i++)
     {
      GetTFBox(tf_idx, i + 1, temp);
      SetTFBox(tf_idx, i, temp);
     }
   SetTFBoxesCount(tf_idx, count - 1);
  }

//+------------------------------------------------------------------+
//| RemoveLaolLine - Remove LaolLineData at index, shift remaining    |
//+------------------------------------------------------------------+
void RemoveLaolLine(LaolLineData &arr[], int &count, int idx)
  {
   if(idx < 0 || idx >= count)
      return;

   for(int i = idx; i < count - 1; i++)
      arr[i] = arr[i + 1];

   count--;
  }

//+------------------------------------------------------------------+
//| RemoveHcsBox - Remove HcsBoxData at index, shift remaining        |
//+------------------------------------------------------------------+
void RemoveHcsBox(HcsBoxData &arr[], int &count, int idx)
  {
   if(idx < 0 || idx >= count)
      return;

   for(int i = idx; i < count - 1; i++)
      arr[i] = arr[i + 1];

   count--;
  }

//+------------------------------------------------------------------+
//| RemoveRrBox - Remove RrBoxSet at index, shift remaining           |
//+------------------------------------------------------------------+
void RemoveRrBox(RrBoxSet &arr[], int &count, int idx)
  {
   if(idx < 0 || idx >= count)
      return;

   for(int i = idx; i < count - 1; i++)
      arr[i] = arr[i + 1];

   count--;
  }

//+------------------------------------------------------------------+
//| DeleteAllObjects - Clean up all STX objects on deinit              |
//+------------------------------------------------------------------+
void DeleteAllObjects()
  {
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, "STX_") == 0)
         ObjectDelete(0, name);
     }
  }

//+------------------------------------------------------------------+
//|                                                                    |
//|          PATTERN DETECTION AND MTF DATA RETRIEVAL                  |
//|                                                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| UpdateSeq - Update sequence state for TBE (Trend Break Entry)     |
//| Exact translation of f_update_seq from Pine Script                |
//| Steps: 0=idle, 1=initial FU/X3, 2=in_zone, 3=counter,            |
//|        4=second_in_zone, 5=completed (valid TBE)                  |
//+------------------------------------------------------------------+
void UpdateSeq(SeqState &seq, bool is_fu, bool is_x3, bool counter_fu,
               bool counter_x3, double level, double body, int tf_minutes,
               bool confirmed, bool is_bear, double p_h, double p_l,
               int &out_step, bool &out_valid)
  {
//--- If not confirmed, return current step and false
   if(!confirmed)
     {
      out_step  = seq.step;
      out_valid = false;
      return;
     }

//--- Calculate candles since start
   int candles_since = 0;
   if(seq.start_time != 0)
     {
      long elapsed_sec = (long)(TimeCurrent() - seq.start_time);
      long tf_sec      = (long)tf_minutes * 60;
      if(tf_sec > 0)
         candles_since = (int)MathRound((double)elapsed_sec / (double)tf_sec);
     }

//--- Timeout: if step > 0 and step < 5 and candles_since > 5, reset
   if(seq.step > 0 && seq.step < 5 && candles_since > 5)
     {
      seq.step       = 0;
      seq.level      = 0.0;
      seq.body       = 0.0;
      seq.start_time = 0;
     }

   bool is_valid = false;

//--- Step 5: completed pattern, reset
   if(seq.step == 5)
     {
      seq.step       = 0;
      seq.level      = 0.0;
      seq.body       = 0.0;
      seq.start_time = 0;
     }
//--- Step 4: waiting for FU to complete
   else if(seq.step == 4)
     {
      bool broke_level = is_bear ? (p_h > seq.level) : (p_l < seq.level);
      if(broke_level)
        {
         seq.step       = 0;
         seq.level      = 0.0;
         seq.body       = 0.0;
         seq.start_time = 0;
        }
      else if(is_fu)
        {
         seq.step = 5;
         is_valid = true;
        }
     }
//--- Step 3: waiting for price to re-enter zone
   else if(seq.step == 3)
     {
      bool broke_level = is_bear ? (p_h > seq.level) : (p_l < seq.level);
      bool in_zone     = is_bear ? (p_h > seq.body && p_h < seq.level) :
                                   (p_l < seq.body && p_l > seq.level);
      if(broke_level)
        {
         seq.step       = 0;
         seq.level      = 0.0;
         seq.body       = 0.0;
         seq.start_time = 0;
        }
      else if(in_zone)
        {
         seq.step = 4;
        }
     }
//--- Step 2: waiting for counter FU or X3
   else if(seq.step == 2)
     {
      bool broke_level = is_bear ? (p_h > seq.level) : (p_l < seq.level);
      if(broke_level)
        {
         seq.step       = 0;
         seq.level      = 0.0;
         seq.body       = 0.0;
         seq.start_time = 0;
        }
      else if(counter_fu || counter_x3)
        {
         seq.step = 3;
        }
     }
//--- Step 1: waiting for price to enter zone, else reset
   else if(seq.step == 1)
     {
      bool broke_level = is_bear ? (p_h > seq.level) : (p_l < seq.level);
      bool in_zone     = is_bear ? (p_h >= seq.body && p_h <= seq.level) :
                                   (p_l <= seq.body && p_l >= seq.level);
      if(broke_level)
        {
         seq.step       = 0;
         seq.level      = 0.0;
         seq.body       = 0.0;
         seq.start_time = 0;
        }
      else if(in_zone)
        {
         seq.step = 2;
        }
      else
        {
         seq.step       = 0;
         seq.level      = 0.0;
         seq.body       = 0.0;
         seq.start_time = 0;
        }
     }

//--- If (is_fu or is_x3) and step == 0, start new sequence
   if((is_fu || is_x3) && seq.step == 0)
     {
      seq.step       = 1;
      seq.level      = level;
      seq.body       = body;
      seq.start_time = TimeCurrent();
     }

   out_step  = seq.step;
   out_valid = is_valid;
  }

//+------------------------------------------------------------------+
//| CalculatePatterns - Detect all patterns for a timeframe bar       |
//| Exact translation of f_calculate_patterns from Pine Script        |
//| Parameters: idx = TF index, p_o2..p_c2 = bar[2] OHLC,           |
//|   p_o1..p_c1 = bar[1] OHLC, p_o..p_c = bar[0] OHLC,            |
//|   p_t = bar time, p_conf = bar confirmed                          |
//+------------------------------------------------------------------+
void CalculatePatterns(int idx, double p_o2, double p_h2, double p_l2, double p_c2,
                       double p_o1, double p_h1, double p_l1, double p_c1,
                       double p_o, double p_h, double p_l, double p_c,
                       datetime p_t, bool p_conf)
  {
//--- Validate data (equivalent of not na() checks in Pine)
   bool valid_data   = (p_h != 0.0 && p_l != 0.0 && p_c != 0.0 && p_o != 0.0);
   bool valid_data_1 = (p_h1 != 0.0 && p_l1 != 0.0 && p_c1 != 0.0 && p_o1 != 0.0);
   bool valid_data_2 = (p_h2 != 0.0 && p_l2 != 0.0 && p_c2 != 0.0 && p_o2 != 0.0);

//--- Both wicks detection (current and previous bar)
   bool both_sides   = valid_data   ? HasBothWicks(p_o, p_h, p_l, p_c)     : false;
   bool both_sides_1 = valid_data_1 ? HasBothWicks(p_o1, p_h1, p_l1, p_c1) : false;

//--- Body top/bottom
   double body_top    = valid_data ? MathMax(p_o, p_c) : 0.0;
   double body_bottom = valid_data ? MathMin(p_o, p_c) : 0.0;

//--- Inside bar detection
   bool is_ib = (valid_data && valid_data_1) ? IsInsideBar(p_h, p_l, p_h1, p_l1) : false;

//--- X3 detection (engulfing with both wicks)
   bool bear_x3 = valid_data && valid_data_1 && p_h > p_h1 && p_l < p_l1 && both_sides && p_c < p_o;
   bool bull_x3 = valid_data && valid_data_1 && p_h > p_h1 && p_l < p_l1 && both_sides && p_c > p_o;
   bool is_x3   = bear_x3 || bull_x3;

//--- X3 on previous bar (bar[1] vs bar[2])
   bool bear_x3_1 = (valid_data_1 && valid_data_2) ? (p_h1 > p_h2 && p_l1 < p_l2 && both_sides_1 && p_c1 < p_o1) : false;
   bool bull_x3_1 = (valid_data_1 && valid_data_2) ? (p_h1 > p_h2 && p_l1 < p_l2 && both_sides_1 && p_c1 > p_o1) : false;
   bool is_x3_1   = bear_x3_1 || bull_x3_1;

//--- SN (Sniper) detection - engulfing wicks but body inside previous range
   bool sn_bull = p_h > p_h1 && p_l < p_l1 && MathMax(p_o, p_c) < p_h1 && MathMin(p_o, p_c) > p_l1 && p_o < p_c;
   bool sn_bear = p_h > p_h1 && p_l < p_l1 && MathMin(p_o, p_c) > p_l1 && MathMax(p_o, p_c) < p_h1 && p_o > p_c;
   bool sn_together = (sn_bull || sn_bear) && !is_x3;

//--- SN on previous bar (bar[1] vs bar[2])
   bool sn_bull_candle_1 = p_h1 > p_h2 && p_l1 < p_l2 && p_c1 > p_o1 && MathMax(p_o1, p_c1) < p_h2;
   bool sn_bear_candle_1 = p_h1 > p_h2 && p_l1 < p_l2 && p_c1 < p_o1 && MathMin(p_o1, p_c1) > p_l2;
   bool sn_together_1 = (sn_bull_candle_1 || sn_bear_candle_1) && !is_x3_1;

//--- LAOL first detection
   bool bull_laol_first = valid_data && valid_data_1 && valid_data_2 &&
                          p_l1 == MathMin(p_o1, p_c1) && p_h1 < p_h2 && p_h < p_h1 && p_l < p_l1;
   bool bear_laol_first = valid_data && valid_data_1 && valid_data_2 &&
                          p_h1 == MathMax(p_o1, p_c1) && p_l1 > p_l2 && p_l > p_l1 && p_h > p_h1;

//--- First EM (Extreme Move) - previous bar was X3/SN and current bar extends beyond it
   bool bear_first_em = (bull_x3_1 || sn_together_1) && p_h > p_h1 && p_l > p_l1;
   bool bull_first_em = (bear_x3_1 || sn_together_1) && p_l < p_l1 && p_h < p_h1;

//--- LAOL candle (inside bar for LAOL purposes)
   bool bear_laol_candle = is_ib;
   bool bull_laol_candle = is_ib;

//--- FU (Fakeout) detection
   bool fu_bear_em = valid_data && valid_data_1 && p_h > p_h1 && p_c < p_h1 && p_c > p_l1 && !is_x3 && !sn_together;
   bool fu_bull_em = valid_data && valid_data_1 && p_l < p_l1 && p_c > p_l1 && p_c < p_h1 && !is_x3 && !sn_together;

//--- Set all detection arrays
   arr_fu_bear[idx]         = fu_bear_em;
   arr_fu_bull[idx]         = fu_bull_em;
   arr_sn_bear[idx]         = sn_bear;
   arr_sn_bull[idx]         = sn_bull;
   arr_first_bear[idx]      = bear_first_em;
   arr_first_bull[idx]      = bull_first_em;
   arr_laol_bear[idx]       = bear_laol_first;
   arr_laol_bull[idx]       = bull_laol_first;
   arr_laol_first_bear[idx] = bear_laol_first;
   arr_laol_first_bull[idx] = bull_laol_first;
   arr_tf_h[idx]            = p_h;
   arr_tf_l[idx]            = p_l;
   arr_tf_bt[idx]           = body_top;
   arr_tf_bb[idx]           = body_bottom;
   arr_tf_t[idx]            = p_t;
   arr_tf_conf[idx]         = p_conf;
   arr_laol_candle_bear[idx] = bear_laol_candle;
   arr_laol_candle_bull[idx] = bull_laol_candle;
  }

//+------------------------------------------------------------------+
//| GetTFData - Retrieve OHLCT data for a specific timeframe          |
//| Returns bars [2], [1], [0] and confirmation status                |
//| In Pine Script, request.security with barstate.isconfirmed gives  |
//| confirmed=true when the bar has just closed. In MT5, we detect    |
//| this by checking if the bar time changed (new bar opened).        |
//+------------------------------------------------------------------+
void GetTFData(int tf_idx, double &o2, double &h2, double &l2, double &c2,
               double &o1, double &h1, double &l1, double &c1,
               double &o0, double &h0, double &l0, double &c0,
               datetime &t0, bool &is_confirmed)
  {
   ENUM_TIMEFRAMES tf = GetTimeframe(TF_MINUTES[tf_idx]);

//--- Bar [2] data (two bars ago)
   o2 = iOpen(_Symbol, tf, 2);
   h2 = iHigh(_Symbol, tf, 2);
   l2 = iLow(_Symbol, tf, 2);
   c2 = iClose(_Symbol, tf, 2);

//--- Bar [1] data (previous bar)
   o1 = iOpen(_Symbol, tf, 1);
   h1 = iHigh(_Symbol, tf, 1);
   l1 = iLow(_Symbol, tf, 1);
   c1 = iClose(_Symbol, tf, 1);

//--- Bar [0] data (current bar)
   o0 = iOpen(_Symbol, tf, 0);
   h0 = iHigh(_Symbol, tf, 0);
   l0 = iLow(_Symbol, tf, 0);
   c0 = iClose(_Symbol, tf, 0);

//--- Current bar time
   t0 = iTime(_Symbol, tf, 0);

//--- Check if a new bar has formed (confirming the previous bar)
//--- In Pine Script, barstate.isconfirmed is true when current bar is closed.
//--- In MT5, when iTime changes, a new bar has opened meaning the bar at shift=1
//--- is now the last confirmed bar. We detect this change to signal confirmation.
   if(t0 != g_prev_tf_time[tf_idx])
     {
      is_confirmed = true;
      g_prev_tf_time[tf_idx] = t0;
     }
   else
     {
      is_confirmed = false;
     }
  }

//+------------------------------------------------------------------+
//| RetrieveAllTFData - Get data and calculate patterns for all TFs   |
//| Calls GetTFData for each timeframe then CalculatePatterns.        |
//| For INTRA timeframes (idx 16-24), only process if InpSoftStart.   |
//+------------------------------------------------------------------+
void RetrieveAllTFData()
  {
   double o2, h2, l2, c2;
   double o1, h1, l1, c1;
   double o0, h0, l0, c0;
   datetime t0;
   bool is_conf;

//--- Process all ENTRY and SCALP timeframes (idx 0-15)
   for(int i = 0; i <= 15; i++)
     {
      GetTFData(i, o2, h2, l2, c2, o1, h1, l1, c1, o0, h0, l0, c0, t0, is_conf);
      CalculatePatterns(i, o2, h2, l2, c2, o1, h1, l1, c1, o0, h0, l0, c0, t0, is_conf);
     }

//--- Process INTRA timeframes (idx 16-24) only if soft_start is enabled
   if(InpSoftStart)
     {
      for(int i = INTRA_MIN_IDX; i <= INTRA_MAX_IDX; i++)
        {
         GetTFData(i, o2, h2, l2, c2, o1, h1, l1, c1, o0, h0, l0, c0, t0, is_conf);
         CalculatePatterns(i, o2, h2, l2, c2, o1, h1, l1, c1, o0, h0, l0, c0, t0, is_conf);
        }
     }
  }

//+------------------------------------------------------------------+
