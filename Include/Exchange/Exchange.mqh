//+------------------------------------------------------------------+
//|                                                     Exchange.mqh |
//|                        Copyright 2015, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

#include "json.mqh"
#include "Model.mqh"
#include "Manager.mqh"
#include "FileMemory.mqh"
#include "Config.mqh"

class MonitorConfigurator : Configurator
{
   MONITOR m_setting;
   
public:
   MonitorConfigurator(MONITOR& setting)
   {
      m_setting.Init(setting);
   }
public:
   void ManagerInit(Manager* &m_managers[])
   {
      if (m_setting.m_managers.m_stopQuotesNotificator.m_enabler)
      {
         NotificationConfigurator* notificationConfigurator = new NotificationConfigurator(m_setting.m_managers.m_stopQuotesNotificator.m_notifications);
         FilterConfigurator* filterConfigurator             = new FilterConfigurator(m_setting.m_managers.m_stopQuotesNotificator.m_filters);
         
         Add(m_managers, (Manager*)new StopQuotesNotificator(notificationConfigurator, filterConfigurator, m_setting.m_managers.m_stopQuotesNotificator.m_timeOut));
         
         if (CheckPointer(notificationConfigurator) == POINTER_DYNAMIC) delete notificationConfigurator;
         if (CheckPointer(filterConfigurator) == POINTER_DYNAMIC)       delete filterConfigurator;
      }
      if (m_setting.m_managers.m_dHunter.m_enabler)
      {
         //NotificationConfigurator* notificationConfigurator = new NotificationConfigurator(m_setting.m_managers.m_stopQuotesNotificator.m_notifications);
         FilterConfigurator* filterConfigurator             = new FilterConfigurator(m_setting.m_managers.m_stopQuotesNotificator.m_filters);
         Add(m_managers, (Manager*)new DHunter(filterConfigurator, m_setting.m_managers.m_stopQuotesNotificator.m_timeOut));
         
         if (CheckPointer(filterConfigurator) == POINTER_DYNAMIC)       delete filterConfigurator;
      }
   }
   void SettingInit(MONITOR& setting)
   {
      setting.Init(m_setting);
   }
};

class Monitor
{
private:
   MONITOR        m_setting;   
   Manager*       m_managers[];
   FileMemory*    m_file;
   HeadWork       m_head;
   DataWork       m_data;
   
public:
   Monitor(MonitorConfigurator* monitorConfigurator)
   {
      monitorConfigurator.ManagerInit(m_managers);
      monitorConfigurator.SettingInit(m_setting);
      Init();
   }
  ~Monitor()
   {
      Deinit();
   }

private:
   void Init()
   {
      m_file = new FileMemory(m_setting.m_prefix + m_setting.m_symbolMemory);
      m_head.Init(m_file);
      m_data.Init(m_file);
   }
   void Deinit()
   {
      m_head.Deinit(m_file);
      
      SData data; data.Fill(m_setting);
      m_data.Deinit(m_file, data);
      
      SHead head; m_head.Read(m_file, head);
      
      if (CheckPointer(m_file) == POINTER_DYNAMIC)
      {
         if (head.Users <= 0) m_file.Deinit(true);
         delete m_file; m_file = NULL;
      }
      
      for (int i = 0; i < ArraySize(m_managers); i++)
      {
         if (CheckPointer(m_managers[i]) == POINTER_DYNAMIC)
         {
            delete m_managers[i]; m_managers[i] = NULL;
         }
      }
   }
   
   // Check quotes update?
   bool isQuotesUpdate(SData &his, SData &alien)
   {
      return (
         NormalizeDouble(his.MQLTick.ask, 5) != NormalizeDouble(alien.MQLTick.ask, 5) ||
         NormalizeDouble(his.MQLTick.bid, 5) != NormalizeDouble(alien.MQLTick.bid, 5));
   }
   
   void Read(SData& datas[], int& index)
   {
      SData data; data.Fill(m_setting);
      if (m_data.Read(m_file, datas))
      {
         STerminal terminal; terminal.Fill();
         m_data.Index(m_file, terminal, index);
      }
   }
   
   void Update(SData& datas[], int& index)
   {
      SData data; data.Fill(m_setting);
      if (m_data.Read(m_file, datas))
      {
         if (m_data.Index(m_file, data.Terminal, index))
         {
            // Update timeout and before tick
            if (isQuotesUpdate(datas[index], data))
            {
               // Update before tick
               data.MQLTickBefore = datas[index].MQLTick;
               
               // Update timeout
               data.LastUpdateQuote = GetMicrosecondCount();
               data.TimeOutQuote = 0;
            }
            else
            {
               data.MQLTickBefore = datas[index].MQLTickBefore;
               data.TimeOutQuote = GetMicrosecondCount() - datas[index].LastUpdateQuote;
               data.LastUpdateQuote = datas[index].LastUpdateQuote;
            }
         }
         else
         {
            data.MQLTickBefore = data.MQLTick;
            data.TimeOutQuote = 0;
            data.LastUpdateQuote = GetMicrosecondCount();
         }
      }
      else
      {
         data.MQLTickBefore = data.MQLTick;
         data.TimeOutQuote = 0;
         data.LastUpdateQuote = GetMicrosecondCount();
      }
      
      m_data.AddOrUpdate(m_file, data);
      m_data.Read(m_file, datas);
      m_data.Index(m_file, data.Terminal, index);
   }
   
   // Working data file
   void Work(SData &datas[], int index)
   {
      for(int i = 0; i < ArraySize(m_managers); i++)
      {
         m_managers[i].Work(datas, index);
      }
   }
   
   void Log(SData &datas[], int index)
   {
      if (Symbol() == m_setting.m_symbolTerminal)
      {
         string m_log = NULL;
         for(int i = 0; i < ArraySize(datas); i++)
         {
            if (i == index) continue;
            
            m_log += Log(datas[index], datas[i]);
         }
         Comment(m_log);
      }
   }
   
   string Log(SData &his, SData &alien)
   {
      string company = CharArrayToString(alien.Terminal.Company);
      int login = alien.Terminal.Login;
      
      double pointBuy  = alien.MQLTick.bid - his.MQLTick.ask;
      double pointSell = his.MQLTick.bid - alien.MQLTick.ask;
      double spreadAverage = ((his.MQLTick.ask - his.MQLTick.bid) + (his.MQLTickBefore.ask - his.MQLTickBefore.bid)) / 2;
      double spreadAverageAlien = ((alien.MQLTick.ask - alien.MQLTick.bid) + (alien.MQLTickBefore.ask - alien.MQLTickBefore.bid)) / 2;
      string text = StringConcatenate(
         company, " : ", login, "\n",
         "-------------------------------------------------------------------", "\n",
         "                           alien                this   ", "\n",
         "  spread              ", DoubleToString(alien.MQLTick.ask - alien.MQLTick.bid, 5), "    |    ", DoubleToString(his.MQLTick.ask - his.MQLTick.bid, 5), "\n",
         "  ask                  ", DoubleToString(alien.MQLTick.ask, 5), "    |    ", DoubleToString(his.MQLTick.ask, 5), "\n",
         "  bid                   ", DoubleToString(alien.MQLTick.bid, 5), "    |    ", DoubleToString(his.MQLTick.bid, 5), "\n"
         "-------------------------------------------------------------------", "\n",
         "  spread before     ", DoubleToString(alien.MQLTickBefore.ask - alien.MQLTickBefore.bid, 5), "    |    ", DoubleToString(his.MQLTickBefore.ask - his.MQLTickBefore.bid, 5), "\n",
         "  ask before         ", DoubleToString(alien.MQLTickBefore.ask, 5), "    |    ", DoubleToString(his.MQLTickBefore.ask, 5), "\n",
         "  bid before          ", DoubleToString(alien.MQLTickBefore.bid, 5), "    |    ", DoubleToString(his.MQLTickBefore.bid, 5), "\n"
         "-------------------------------------------------------------------", "\n");
       return text + StringConcatenate(
         "  TimeOut           ", DoubleToString(alien.TimeOutQuote * 0.000001, 1), " sec.     |    ", DoubleToString(his.TimeOutQuote * 0.000001, 1), " sec.\n",
         "  LastUpdate        ", TimeToString(alien.LastUpdateExpert, TIME_MINUTES|TIME_SECONDS), "    |    ", TimeToString(his.LastUpdateExpert, TIME_MINUTES|TIME_SECONDS), "\n",
         "  Spread avg        ", DoubleToString(spreadAverageAlien, 5), "    |     ", DoubleToString(spreadAverage, 5), "    \n",
         "  TradeAllowed      ", alien.isTradeAllowed, "        |      ", his.isTradeAllowed, "          \n",
         "-------------------------------------------------------------------", "\n",
         "  Buy:                " , DoubleToString(NormalizeDouble(spreadAverage, 5) > 0 ? pointBuy / spreadAverage : 0,  2), " sp.    |   ", DoubleToString(pointBuy,  5), " pt.", "\n",
         "  Sell:                 ", DoubleToString(NormalizeDouble(spreadAverage, 5) > 0 ? pointSell / spreadAverage : 0, 2), " sp.    |   ", DoubleToString(pointSell, 5), " pt.", "\n",
         //"     Stop quotes: ", string(status), "\n",
         "-------------------------------------------------------------------", "\n\n"
      );
   }
   
public:
   void Working()
   {
      //if(SymbolSelect(m_setting.m_symbolTerminal, true))
      //{
         SData datas[]; int index = 0;
         if (m_setting.m_updater)
            this.Update(datas, index);
         else
            this.Read(datas, index);
         
         this.Work(datas, index);
         
         if (m_setting.m_logger)
            this.Log(datas, index);
      //}
   }
};

class ExpertConfigurator : Configurator
{
   EXPERT m_expert;
public:
   ExpertConfigurator(EXPERT& expert)
   {
      m_expert.Init(expert);
   }
   
   void MonitorsInit(Monitor* &monitor)
   {
      if(SymbolSelect(m_expert.m_monitor.m_symbolTerminal, true))
      {
         MonitorConfigurator* monitorConfigurator = new MonitorConfigurator(m_expert.m_monitor);
         if (CheckPointer(monitor) == POINTER_DYNAMIC) delete monitor;
         monitor = new Monitor(monitorConfigurator);
         if (CheckPointer(monitorConfigurator) == POINTER_DYNAMIC) delete monitorConfigurator;
      }
   }
};

class Expert
{
   Monitor* m_monitor;
   
public:
   Expert(ExpertConfigurator* expertConfigurator)
   {
      expertConfigurator.MonitorsInit(m_monitor);
   }
  ~Expert()
   {
      if (CheckPointer(m_monitor) == POINTER_DYNAMIC)
      {
         delete m_monitor; m_monitor = NULL;
      }
   }
   
   void Working()
   {
      m_monitor.Working();
   }
};
