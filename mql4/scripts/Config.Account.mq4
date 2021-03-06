/**
 * Schickt dem ChartInfos-Indikator des aktuellen Charts die Nachricht, die Konfigurationsdatei des aktuellen Accounts in den
 * Editor zu laden.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[] = { INIT_NO_BARS_REQUIRED };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   string label = "ChartInfos.command";
   string mutex = "mutex."+ label;

   // Schreibzugriff auf Command-Object synchronisieren (Lesen ist ohne Lock m�glich)
   if (!AquireLock(mutex, true))
      return(ERR_RUNTIME_ERROR);

   // Command setzen                                                 // TODO: Command zu bereits existierenden Commands hinzuf�gen
   if (ObjectFind(label) != 0) {
      if (!ObjectCreate(label, OBJ_LABEL, 0, 0, 0))                return(_int(catch("onStart(1)"), ReleaseLock(mutex)));
      if (!ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE)) return(_int(catch("onStart(2)"), ReleaseLock(mutex)));
   }
   if (!ObjectSetText(label, "cmd=EditAccountConfig"))             return(_int(catch("onStart(3)"), ReleaseLock(mutex)));

   // Schreibzugriff auf Command-Object freigeben
   if (!ReleaseLock(mutex))
      return(ERR_RUNTIME_ERROR);

   // Tick senden
   Chart.SendTick();
   return(catch("onStart(4)"));
}
