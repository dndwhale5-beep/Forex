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
