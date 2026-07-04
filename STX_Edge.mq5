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
