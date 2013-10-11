/**
 * In Headerdatei implementiert, um direkt in EA's inkludiert werden zu k�nnen.  Dies ist notwendig, wenn die Indikatorausgabe
 * im Tester nach Testende bei VisualMode=On gezeichnet werden soll.  Der Tester zeichnet den Inhalt der Buffer nur dann, wenn
 * der iCustom()-Aufruf direkt im EA erfolgt (nicht bei Aufruf in einer Library).
 */

#import "structs1.ex4"
   int  ec.LastError(/*EXECUTION_CONTEXT*/int ec[]);
#import


/**
 * Berechnet den angegebenen Wert des "Moving Average"-Indikators und gibt ihn zur�ck.
 *
 * @param  int    timeframe      - Timeframe, in dem der Indikator geladen wird
 * @param  string maPeriods      - Indikator-Parameter
 * @param  string maTimeframe    - Indikator-Parameter
 * @param  string maMethod       - Indikator-Parameter
 * @param  string maAppliedPrice - Indikator-Parameter
 * @param  int    iBuffer        - Bufferindex des zur�ckzugebenden Wertes
 * @param  int    iBar           - Barindex des zur�ckzugebenden Wertes
 *
 * @return double - Wert oder 0, falls ein Fehler auftrat
 */
double icMovingAverage(int timeframe, string maPeriods, string maTimeframe, string maMethod, string maAppliedPrice, int iBuffer, int iBar) {
   if (IsLastError())
      return(0);

   int maMaxValues    = 10;                                                // mindestens 10 Werte berechnen, um vorherrschenden Trend korrekt zu detektieren
   int lpLocalContext = GetBufferAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "Moving Average",
                          maPeriods,                                       // MA.Periods
                          maTimeframe,                                     // MA.Timeframe
                          maMethod,                                        // MA.Method
                          maAppliedPrice,                                  // AppliedPrice
                          ForestGreen,                                     // Color.UpTrend
                          Red,                                             // Color.DownTrend
                          maMaxValues,                                     // Max.Values
                          0,                                               // Shift.Horizontal.Bars
                          0,                                               // Shift.Vertical.Pips
                          "",                                              // ________________
                          lpLocalContext,                                  // __SuperContext__
                          iBuffer, iBar);                                  // throws ERS_HISTORY_UPDATE, ERR_TIMEFRAME_NOT_AVAILABLE

   int error = GetLastError();

   if (IsError(error)) {
      if (error != ERS_HISTORY_UPDATE)
         return(_NULL(catch("icMovingAverage(1)", error)));
      warn("icMovingAverage(2)   ERS_HISTORY_UPDATE (tick="+ Tick +")");   // TODO: geladene Bars pr�fen
   }

   error = ec.LastError(__ExecutionContext);                               // TODO: Synchronisation von Original und Kopie sicherstellen
   if (!error)
      return(value);

   return(_NULL(SetLastError(error)));
}