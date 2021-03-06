/**
 *
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

#property show_inputs

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern datetime Trades.Startdate    = D'2016.01.01';
extern string   Trades.Directions   = "Long | Short | Both*";
extern string   _______________________________;
extern int      BB.Periods          = 40;
extern int      BB.Deviation        = 2;
extern int      Open.Max.Positions  = 3;                 // maximum number of open positions per direction
extern int      Open.Min.Distance   = 0;                 // minimum distance of positions per direction in pips
extern bool     Close.One.In.Profit = true;              // whether to close positions only if at least one is profitable

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/iBarShiftNext.mqh>
#include <functions/iBarShiftPrevious.mqh>


// trading configuration
int trade.directions = TRADE_DIRECTIONS_BOTH;
int ticket           = 0;                                // virtual ticket number

// position tracking
int      long.positions      = 0;
double   long.lastEntryLevel = INT_MAX;
int      long.tickets   [];
datetime long.openTimes [];
double   long.openPrices[];

int      short.positions      = 0;
double   short.lastEntryLevel = INT_MIN;
int      short.tickets   [];
datetime short.openTimes [];
double   short.openPrices[];



// order marker colors
#define CLR_OPEN_LONG      C'0,0,254'                    // Blue - rgb(1,1,1)
#define CLR_OPEN_SHORT     C'254,0,0'                    // Red  - rgb(1,1,1)
#define CLR_CLOSE          Orange


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate input parameters
   // Trades.Direction
   string strValue, elems[];
   if (Explode(Trades.Directions, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      strValue = elems[size-1];
   }
   else strValue = Trades.Directions;
   trade.directions = StrToTradeDirection(strValue, F_ERR_INVALID_PARAMETER);
   if (trade.directions <= 0 || trade.directions > TRADE_DIRECTIONS_BOTH)
      return(catch("onInit(1)  Invalid input parameter Trades.Directions = "+ DoubleQuoteStr(Trades.Directions), ERR_INVALID_INPUT_PARAMETER));
   Trades.Directions = TradeDirectionDescription(trade.directions);

   return(catch("onInit(2)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   // (1) calculate start bar                                  // TODO: check available bars for indicator calculation
   int bar = iBarShiftPrevious(NULL, NULL, Trades.Startdate);
   if (bar == -1) return(catch("onStart(1)  No history found for "+ TimeToStr(Trades.Startdate, TIME_DATE|TIME_MINUTES), ERR_HISTORY_INSUFFICIENT));

   int startBar = iBarShiftNext(NULL, NULL, Trades.Startdate);
   if (startBar == -1) return(catch("onStart(2)  History not loaded for "+ TimeToStr(Trades.Startdate, TIME_DATE|TIME_MINUTES), ERR_HISTORY_INSUFFICIENT));


   // (2) calculate signals for each bar
   for (bar=startBar; bar >= 0; bar--) {
      // check long conditions
      if (trade.directions & TRADE_DIRECTIONS_LONG && 1) {
         int lastPositions = long.positions;
         if (long.positions < Open.Max.Positions)             Long.CheckOpenSignal(bar);
         if (long.positions && long.positions==lastPositions) Long.CheckCloseSignal(bar);    // don't check for close on an open signal
      }

      // check short conditions
      if (trade.directions & TRADE_DIRECTIONS_SHORT && 1) {
         lastPositions = short.positions;
         if (short.positions < Open.Max.Positions)              Short.CheckOpenSignal(bar);
         if (short.positions && short.positions==lastPositions) Short.CheckCloseSignal(bar); // don't check for close on an open signal
      }
   }
   return(catch("onStart(3)"));
}


/**
 * Check for long entry conditions.
 *
 * @param  int bar - bar offset
 */
void Long.CheckOpenSignal(int bar) {
   if (Close[bar+2] < iBands(NULL, NULL, BB.Periods, BB.Deviation, 0, PRICE_CLOSE, MODE_LOWER, bar+2) && Close[bar+1] > iBands(NULL, NULL, BB.Periods, BB.Deviation, 0, PRICE_CLOSE, MODE_LOWER, bar+1)) {
      if (Close[bar+1] < iBands(NULL, NULL, BB.Periods, BB.Deviation, 0, PRICE_CLOSE, MODE_MAIN, bar+1)) {
         if (Open[bar] < long.lastEntryLevel - Open.Min.Distance*Pips) {
            ticket++;
            ArrayPushInt   (long.tickets,    ticket   );
            ArrayPushInt   (long.openTimes,  Time[bar]);
            ArrayPushDouble(long.openPrices, Open[bar]);
            long.positions++;
            long.lastEntryLevel = Open[bar];

            MarkOpen(OP_LONG, ticket, Time[bar], Open[bar]);
         }
      }
   }
}


/**
 * Check for long exit conditions.
 *
 * @param  int bar - bar offset
 */
void Long.CheckCloseSignal(int bar) {
   if (Close[bar+1] > iBands(NULL, NULL, BB.Periods, BB.Deviation, 0, PRICE_CLOSE, MODE_MAIN, bar+1)) {
      if (!Close.One.In.Profit || long.lastEntryLevel < Open[bar]) {
         for (int i=0; i < long.positions; i++) {
            MarkClose(OP_LONG, long.tickets[i], long.openTimes[i], long.openPrices[i], Time[bar], Open[bar]);
         }
         ArrayResize(long.tickets,    0);
         ArrayResize(long.openTimes,  0);
         ArrayResize(long.openPrices, 0);
         long.positions      = 0;
         long.lastEntryLevel = INT_MAX;
      }
   }
}


/**
 * Check for short entry conditions.
 *
 * @param  int bar - bar offset
 */
void Short.CheckOpenSignal(int bar) {
   if (Close[bar+2] > iBands(NULL, NULL, BB.Periods, BB.Deviation, 0, PRICE_CLOSE, MODE_UPPER, bar+2) && Close[bar+1] < iBands(NULL, NULL, BB.Periods, BB.Deviation, 0, PRICE_CLOSE, MODE_UPPER, bar+1)) {
      if (Close[bar+1] > iBands(NULL, NULL, BB.Periods, BB.Deviation, 0, PRICE_CLOSE, MODE_MAIN, bar+1)) {
         if (Open[bar] > short.lastEntryLevel + Open.Min.Distance*Pips) {
            ticket++;
            ArrayPushInt   (short.tickets,    ticket   );
            ArrayPushInt   (short.openTimes,  Time[bar]);
            ArrayPushDouble(short.openPrices, Open[bar]);
            short.positions++;
            short.lastEntryLevel = Open[bar];

            MarkOpen(OP_SHORT, ticket, Time[bar], Open[bar]);
         }
      }
   }
}


/**
 * Check for short exit conditions.
 *
 * @param  int bar - bar offset
 */
void Short.CheckCloseSignal(int bar) {
   if (Close[bar+1] < iBands(NULL, NULL, BB.Periods, BB.Deviation, 0, PRICE_CLOSE, MODE_MAIN, bar+1)) {
      if (!Close.One.In.Profit || short.lastEntryLevel > Open[bar]) {
         for (int i=0; i < short.positions; i++) {
            MarkClose(OP_SHORT, short.tickets[i], short.openTimes[i], short.openPrices[i], Time[bar], Open[bar]);
         }
         ArrayResize(short.tickets,    0);
         ArrayResize(short.openTimes,  0);
         ArrayResize(short.openPrices, 0);
         short.positions      = 0;
         short.lastEntryLevel = INT_MIN;
      }
   }
}


/**
 * Draw an "open position" marker in the chart.
 *
 * @param  int      direction - trade direction: OP_LONG|OP_SHORT
 * @param  int      ticket    - ticket number
 * @param  datetime time      - position open time
 * @param  double   price     - position open price
 */
void MarkOpen(int direction, int ticket, datetime time, double price) {
   if (direction == OP_LONG) {
      string label = StringConcatenate("#", ticket, " buy at ", NumberToStr(price, PriceFormat));
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_ARROW, 0, time, price)) {
         ObjectSet(label, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
         ObjectSet(label, OBJPROP_COLOR,     CLR_OPEN_LONG   );
      }
      return;
   }

   if (direction == OP_SHORT) {
      label = StringConcatenate("#", ticket, " sell at ", NumberToStr(price, PriceFormat));
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_ARROW, 0, time, price)) {
         ObjectSet(label, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
         ObjectSet(label, OBJPROP_COLOR,     CLR_OPEN_SHORT  );
      }
      return;
   }

   catch("MarkOpen(1)  invalid parameter direction = "+ direction, ERR_INVALID_PARAMETER);
}


/**
 * Draw a "close position" marker and the connecting line in the chart.
 *
 * @param  int      direction  - trade direction: OP_LONG|OP_SHORT
 * @param  int      ticket     - ticket number
 * @param  datetime openTime   - position open time
 * @param  double   openPrice  - position open price
 * @param  datetime closeTime  - position close time
 * @param  double   closePrice - position close price
 */
void MarkClose(int direction, int ticket, datetime openTime, double openPrice, datetime closeTime, double closePrice) {
   int lineColors[] = {Blue, Red};

   string sOpenPrice  = NumberToStr(openPrice, PriceFormat);
   string sClosePrice = NumberToStr(closePrice, PriceFormat);


   if (direction == OP_LONG) {
      // connecting line
      string lineLabel = StringConcatenate("#", ticket, " ", sOpenPrice, " -> ", sClosePrice);
      if (ObjectFind(lineLabel) == 0)
         ObjectDelete(lineLabel);
      if (ObjectCreate(lineLabel, OBJ_TREND, 0, openTime, openPrice, closeTime, closePrice)) {
         ObjectSet(lineLabel, OBJPROP_RAY  , false                );
         ObjectSet(lineLabel, OBJPROP_STYLE, STYLE_DOT            );
         ObjectSet(lineLabel, OBJPROP_COLOR, lineColors[direction]);
         ObjectSet(lineLabel, OBJPROP_BACK , true                 );
      }

      // close marker
      string closeLabel = StringConcatenate("#", ticket, " close buy at ", sClosePrice);
      if (ObjectFind(closeLabel) == 0)
         ObjectDelete(closeLabel);
      if (ObjectCreate(closeLabel, OBJ_ARROW, 0, closeTime, closePrice)) {
         ObjectSet(closeLabel, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
         ObjectSet(closeLabel, OBJPROP_COLOR    , CLR_CLOSE        );
      }
      return;
   }


   if (direction == OP_SHORT) {
      // connecting line
      lineLabel = StringConcatenate("#", ticket, " ", sOpenPrice, " -> ", sClosePrice);
      if (ObjectFind(lineLabel) == 0)
         ObjectDelete(lineLabel);
      if (ObjectCreate(lineLabel, OBJ_TREND, 0, openTime, openPrice, closeTime, closePrice)) {
         ObjectSet(lineLabel, OBJPROP_RAY  , false                );
         ObjectSet(lineLabel, OBJPROP_STYLE, STYLE_DOT            );
         ObjectSet(lineLabel, OBJPROP_COLOR, lineColors[direction]);
         ObjectSet(lineLabel, OBJPROP_BACK , true                 );
      }

      // close marker
      closeLabel = StringConcatenate("#", ticket, " close sell at ", sClosePrice);
      if (ObjectFind(closeLabel) == 0)
         ObjectDelete(closeLabel);
      if (ObjectCreate(closeLabel, OBJ_ARROW, 0, closeTime, closePrice)) {
         ObjectSet(closeLabel, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
         ObjectSet(closeLabel, OBJPROP_COLOR    , CLR_CLOSE        );
      }
      return;
   }

   catch("MarkClose(1)  invalid parameter direction = "+ direction, ERR_INVALID_PARAMETER);
}
