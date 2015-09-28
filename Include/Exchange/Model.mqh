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

// DATA MODEL -------------------------------------------------------

// CHECKER MODEL ----------------------------------------------------

struct MIN_DEVIATION
{
   bool     m_enabler;
   double   m_buyDeviation;
   double   m_sellDeviation;

public:
   void Init(bool enabler = false, double buyDeviation = 0, double sellDeviation = 0)  { m_enabler = enabler; m_buyDeviation = buyDeviation; m_sellDeviation = sellDeviation; }
   void Init(MIN_DEVIATION& settings)                                                  { Init(settings.m_enabler, settings.m_buyDeviation, settings.m_sellDeviation); }
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
   void Init()
   {
      MIN_DEVIATION  minPointDeviation; minPointDeviation.Init();
      MIN_DEVIATION  minSpreadDeviation;minSpreadDeviation.Init();
      Init(minPointDeviation, minSpreadDeviation);
   }
};


struct TIMEOUT
{
   bool     m_enabler;
   double   m_timeOutSeconds;
   double   m_timeOutExpertSeconds;
   
   void Init(bool enabler = true, double timeOutSeconds = 30, double timeOutExpertSeconds = 3)   { m_enabler = enabler; m_timeOutSeconds = timeOutSeconds; m_timeOutExpertSeconds = timeOutExpertSeconds; }
   void Init(TIMEOUT& timeOut)                                                                   { Init(timeOut.m_enabler, timeOut.m_timeOutSeconds, timeOut.m_timeOutExpertSeconds ); }
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
   void Init()
   {
      ALERT_NOTIFICATION   alert; alert.Init();
      EMAIL_NOTIFICATION   email; email.Init();
      PUSH_NOTIFICATION    push;  push.Init();
      Init(alert, email, push);
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
   void Init()
   {
      TIMEOUT timeOut; timeOut.Init();
      FILTERS filters; filters.Init();
      NOTIFICATIONS notifications; notifications.Init();
      Init(false, timeOut, filters, notifications);
   }
};

struct DHUNTER
{
   bool m_enabler;
   
   void Init(bool enabler)
   {
      m_enabler = enabler;
   }
   void Init(DHUNTER& setting)
   {
      Init(setting.m_enabler);
   }
   void Init()
   {
      Init(false);
   }
};

struct MANAGERS
{
   STOP_QUOTES_NOTIFICATOR m_stopQuotesNotificator;
   DHUNTER                 m_dHunter;
   
   void Init(STOP_QUOTES_NOTIFICATOR& stopQuotesNotificator, DHUNTER& dHunter)
   {
      m_stopQuotesNotificator.Init(stopQuotesNotificator);
      m_dHunter.Init(dHunter);
   }
   void Init(MANAGERS& managers)
   {
      Init(managers.m_stopQuotesNotificator, managers.m_dHunter);
   }
   void Init()
   {
      STOP_QUOTES_NOTIFICATOR stopQuotesNotificator; stopQuotesNotificator.Init();
      DHUNTER dHunter; dHunter.Init();
      Init(stopQuotesNotificator, dHunter);
   }
};
struct MONITOR
{
   // Symbol name in terminal and in memory
   string   m_symbolTerminal;
   string   m_symbolMemory;
   string   m_prefix;
   int      m_UTC;
   bool     m_updater;
   bool     m_logger;
   MANAGERS m_managers;
   
public:
   void Init(string     symbolTerminal,
             string     symbolMemory,
             string     prefix,
             int        UTC,
             bool       updater,
             bool       logger,
             MANAGERS&  managers)
   {
      m_symbolTerminal = symbolTerminal; m_symbolMemory = symbolMemory; m_prefix = prefix; m_UTC = UTC; m_updater = updater; m_logger = logger; m_managers.Init(managers);
   }
   void Init(MONITOR& settings)
   {
      Init(settings.m_symbolTerminal, settings.m_symbolMemory, settings.m_prefix, settings.m_UTC, settings.m_updater, settings.m_logger, settings.m_managers);
   }
   void Init()
   {
      MANAGERS managers; managers.Init();
      Init("Default", "Default", "Local", 0, false, false, managers);
   }
};

enum EData
{
   DataTerminalOffset         = 0,
   DataTSymboOffset           = 204,
   DataMqlTickOffset          = 216,
   DataLastUpdateQuoteOffset  = 256,
   DataTimeOutQuote           = 264,
   DataMqlTickBeforeOffset    = 272,
   DataLastUpdateExpert       = 312,
   DataisTradeAllowed         = 320
};
struct SData // field info for 1 terminal
{
   STerminal   Terminal;             // login info
   char        TSymbol[12];          // Symbol Terminal info
   MqlTick     MQLTick;              // tick current info
   ulong       LastUpdateQuote;      // LastUpdateMickrosecondQuote
   ulong       TimeOutQuote;         // TimeOutMickrosecondQuote
   MqlTick     MQLTickBefore;        // tick before info
   datetime    LastUpdateExpert;     // Last time update expert
   bool        isTradeAllowed;       // Trade allow symbol on this time
   
   void Fill(MONITOR& monitor)
   {
      Terminal.Fill();
      SymbolInfoTick(monitor.m_symbolTerminal, MQLTick);
      StringToCharArray(monitor.m_symbolTerminal, TSymbol);
      LastUpdateExpert = TimeGMT();
      isTradeAllowed = IsTradeAllowed(monitor.m_symbolTerminal, TimeGMT() + (monitor.m_UTC * 3600));
   }
};
struct FileStruct // file structe
{
   SHead Head;
   SData Data[];
};



// CHECKER MODEL -----------------------------------------------------

// NOTIFICATION MODEL ------------------------------------------------


// NOTIFICATION MODEL ------------------------------------------------

// SETTINGS EXPERT ---------------------------------------------------


struct EXPERT
{
   int      m_updateMilliSecondsExpert;
   MONITOR  m_monitor;
   
   void Init(int updateMilliSecondsExpert, MONITOR& monitor)
   {
      m_updateMilliSecondsExpert = updateMilliSecondsExpert;
      m_monitor.Init(monitor);
   }
   void Init(EXPERT& expert)
   {
      Init(expert.m_updateMilliSecondsExpert, expert.m_monitor);
   }
};
// SETTINGS EXPERT ---------------------------------------------------