//+------------------------------------------------------------------+
//|                                                        Model.mqh |
//|                                 Copyright 2015, Solomatov Sergey |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, Solomatov Sergey"
#property link      ""
#property strict


// DATA MODEL -------------------------------------------------------

struct SByte
{
   uchar V[1000];
};

enum EHead
{
   UsersOffset      = 0,
   TerminalsOffset  = 4
};
struct SHead // head info file
{
   uint Users;    // Count users used
   uint Terminals;// Count Terminals file to write
};
enum ETerminal
{
   TerminalOffset = 0,
   LoginOffset = 100,
   CompanyOffset = 104
};
struct STerminal // uniq info for 1 client
{
   char Terminal[100];
   int  Login;
   char Company[100];
   
   void Fill()
   {
      StringToCharArray(TerminalName(), Terminal);
      Login = AccountNumber();
      StringToCharArray(AccountCompany(), Company);
   }
};
enum EData
{
   DataTerminalOffset         = 0,
   DataTSymboOffset           = 204,
   DataMqlTickOffset          = 216,
   DataLastUpdateQuoteOffset  = 256,
   DataTimeOutQuote           = 264,
   DataMqlTickBeforeOffset    = 272
   //DataAverageSpread          = 312
};
struct SData // field info for 1 terminal
{
   STerminal   Terminal;             // login info
   char        TSymbol[12];          // Symbol Terminal info
   MqlTick     MQLTick;              // tick current info
   ulong       LastUpdateQuote;      // LastUpdateMickrosecondQuote
   ulong       TimeOutQuote;         // TimeOutMickrosecondQuote
   MqlTick     MQLTickBefore;        // tick before info
   //double      AverageSpread;        // Average spread for symbol (last 100 ticks)
   
   void Fill(string symbol)
   {
      Terminal.Fill();
      SymbolInfoTick(symbol, MQLTick);
      StringToCharArray(symbol, TSymbol);
   }
};
struct FileStruct // file structe
{
   SHead Head;
   SData Data[];
};


// DATA MODEL -------------------------------------------------------

// CHECKER MODEL ----------------------------------------------------

struct MIN_DEVIATION
{
   bool     m_enabler;
   double   m_buyDeviation;
   double   m_sellDeviation;

public:
   void Init(bool enabler, double buyDeviation, double sellDeviation)  { m_enabler = enabler; m_buyDeviation = buyDeviation; m_sellDeviation = sellDeviation; }
   void Init(MIN_DEVIATION& settings)                                  { Init(settings.m_enabler, settings.m_buyDeviation, settings.m_sellDeviation); }
};

struct FILTERS
{
   MIN_DEVIATION  m_minPointDeviation;
   MIN_DEVIATION  m_minSpreadDeviation;
   
   void Init(MIN_DEVIATION& minPointDeviation, MIN_DEVIATION& minSpreadDeviation)
   {
      m_minPointDeviation.Init(minPointDeviation);
      m_minSpreadDeviation.Init(minSpreadDeviation);
   }
   void Init(FILTERS& filters)
   {
      Init(filters.m_minPointDeviation, filters.m_minSpreadDeviation);
   }
};


struct TIMEOUT
{
   bool     m_enabler;
   double   m_timeOutSeconds;
   
   void Init(bool enabler = true, double timeOutSeconds = 30)  { m_enabler = enabler; m_timeOutSeconds = timeOutSeconds; }
   void Init(TIMEOUT& timeOut)                                 { Init(timeOut.m_enabler, timeOut.m_timeOutSeconds);      }
};

struct NOTIFICATION
{
   bool   m_enabler;
   uint   m_countLimit;        // максимальное количество корректно отправленных сигналов
   double m_resetCountMin;     // количество time, после которых сбрасывается счетчик Count - количество отправленных сигналов
   
public:
   void Init(bool enabler = true, uint countLimit = 1, double resetCountMin = 1) { m_enabler = enabler; m_countLimit = countLimit; m_resetCountMin = resetCountMin; }
   void Init(NOTIFICATION& notification) { Init(notification.m_enabler, notification.m_countLimit, notification.m_resetCountMin); }
};

struct ALERT_NOTIFICATION : NOTIFICATION
{
   void Init(ALERT_NOTIFICATION& settings)
   {
      Init(settings.m_enabler, settings.m_countLimit, settings.m_resetCountMin);
   }
};

struct PUSH_NOTIFICATION : NOTIFICATION
{
   void Init(PUSH_NOTIFICATION& settings)
   {
      Init(settings.m_enabler, settings.m_countLimit, settings.m_resetCountMin);
   }
};

struct EMAIL_NOTIFICATION : NOTIFICATION
{
   string m_header;
   
   void Init(EMAIL_NOTIFICATION& settings)
   {
      Init(settings.m_enabler, settings.m_countLimit, settings.m_resetCountMin); m_header = settings.m_header;
   }
};

struct NOTIFICATIONS
{
   ALERT_NOTIFICATION   m_alert;
   EMAIL_NOTIFICATION   m_email;
   PUSH_NOTIFICATION    m_push;
   
public:
   void Init(ALERT_NOTIFICATION& alert, EMAIL_NOTIFICATION& email, PUSH_NOTIFICATION& push)
   {
      m_alert.Init(alert);
      m_email.Init(email);
      m_push.Init(push);
   }
   void Init(NOTIFICATIONS& notificationSettings)
   {
      Init(notificationSettings.m_alert, notificationSettings.m_email, notificationSettings.m_push);
   }
};


struct STOP_QUOTES_NOTIFICATOR
{
   bool           m_enabler;
   TIMEOUT        m_timeOut;
   FILTERS        m_filters;
   NOTIFICATIONS  m_notifications;
   
public:
   void Init(bool enabler, TIMEOUT& timeOut, FILTERS& filters, NOTIFICATIONS& notifications)
   {
      m_enabler = enabler;
      m_timeOut.Init(timeOut);
      m_filters.Init(filters);
      m_notifications.Init(notifications);
   }
   void Init(STOP_QUOTES_NOTIFICATOR& stopQuotesNotificator)
   {
      Init(stopQuotesNotificator.m_enabler, stopQuotesNotificator.m_timeOut, stopQuotesNotificator.m_filters, stopQuotesNotificator.m_notifications);
   }
};

struct MANAGERS
{
   STOP_QUOTES_NOTIFICATOR m_stopQuotesNotificator;
   
   void Init(STOP_QUOTES_NOTIFICATOR& stopQuotesNotificator)
   {
      m_stopQuotesNotificator.Init(stopQuotesNotificator);
   }
   void Init(MANAGERS& managers)
   {
      Init(managers.m_stopQuotesNotificator);
   }
};

// CHECKER MODEL -----------------------------------------------------

// NOTIFICATION MODEL ------------------------------------------------


// NOTIFICATION MODEL ------------------------------------------------

// SETTINGS EXPERT ---------------------------------------------------
struct MONITOR
{
   // Symbol name in terminal and in memory
   string   m_symbolTerminal;
   string   m_symbolMemory;
   string   m_prefix;
   MANAGERS m_managers;
   
public:
   void Init(string     symbolTerminal,
             string     symbolMemory,
             string     prefix,
             MANAGERS&  managers)
   {
      m_symbolTerminal = symbolTerminal; m_symbolMemory = symbolMemory; m_prefix = prefix; m_managers.Init(managers);
   }
   void Init(MONITOR& settings)
   {
      Init(settings.m_symbolTerminal, settings.m_symbolMemory, settings.m_prefix, settings.m_managers);
   }
};

struct EXPERT
{
   int      m_updateMilliSecondsExpert;
   MONITOR  m_monitors[];
   
   void Init(int updateMilliSecondsExpert, MONITOR& monitors[])
   {
      m_updateMilliSecondsExpert = updateMilliSecondsExpert;
      
      ArrayResize(m_monitors, ArraySize(monitors));
      for (int i = 0; i < ArraySize(m_monitors); i++)
      {
         m_monitors[i].Init(monitors[i]);
      }
   }
   void Init(EXPERT& expert)
   {
      Init(expert.m_updateMilliSecondsExpert, expert.m_monitors);
   }
};
// SETTINGS EXPERT ---------------------------------------------------