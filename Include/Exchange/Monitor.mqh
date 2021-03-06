//+------------------------------------------------------------------+
//|                                                     Exchange.mqh |
//|                        Copyright 2015, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

#include "Model.mqh"
#include "Managers\Manager.mqh"
#include "Managers\StopQuotesNotificator.mqh"
#include "Managers\DHunter.mqh"
#include "Managers\AmirWork.mqh"
#include "FileWork\FileMemory.mqh"
#include "Config\Config.mqh"

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
         
         Add(m_managers, (Manager*)new StopQuotesNotificator(notificationConfigurator, filterConfigurator, m_setting.m_managers.m_stopQuotesNotificator.m_timeOut, m_setting.m_managers.m_stopQuotesNotificator.m_logger, m_setting.m_managers.m_stopQuotesNotificator.m_enabler));
         
         if (CheckPointer(notificationConfigurator) == POINTER_DYNAMIC) delete notificationConfigurator;
         if (CheckPointer(filterConfigurator) == POINTER_DYNAMIC)       delete filterConfigurator;
      }
      if (m_setting.m_managers.m_dHunter.m_enabler)
      {
         //FilterConfigurator* filterConfigurator             = new FilterConfigurator(m_setting.m_managers.m_dHunter.m_filters);
         Add(m_managers, (Manager*)new DHunter(m_setting.m_managers.m_dHunter));
         
         //if (CheckPointer(filterConfigurator) == POINTER_DYNAMIC)       delete filterConfigurator;
      }
      
      if (m_setting.m_managers.m_amir.m_enabler)
      {
         //FilterConfigurator* filterConfigurator             = new FilterConfigurator(m_setting.m_managers.m_stopQuotesNotificator.m_filters);
         Add(m_managers, (Manager*)new  Amir(m_setting.m_managers.m_amir));
         
         //if (CheckPointer(filterConfigurator) == POINTER_DYNAMIC)       delete filterConfigurator;
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
               ulong count = GetMicrosecondCount();
               data.TimeOutQuote = count < datas[index].LastUpdateQuote ? 0 : (count - datas[index].LastUpdateQuote);
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

public:
   void Working()
   {
      SData datas[]; int index = 0;
      if (m_setting.m_updater)
         this.Update(datas, index);
      else
         this.Read(datas, index);
      
      this.Work(datas, index);
   }
};
