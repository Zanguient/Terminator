//+------------------------------------------------------------------+
//|                                              DeviationQuotes.mqh |
//|                                 Copyright 2015, Solomatov Sergey |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, Solomatov Sergey"
#property link      ""
#property strict

#include "Manager.mqh"

// seald class
class Filter
{
public:
   Filter() { Enable(true); }

protected:
   bool m_enabler;
   
protected:
   virtual bool VCheck(SData &his, SData &alien)
   {
      return true;
   }

public:
   // if filter disable, return true
   // if check successful, return true, otherwise fale
   bool Check(SData &his, SData &alien)
   {
      if (!m_enabler) return true;
      
      return VCheck(his, alien);
   }
   
   void Enable(bool enabler = true) { m_enabler = enabler; }
};

void CalculateTick(SData& his, SData& alien, double& calculatedAsk, double& clculatedBid)
{
   double spreadCurrent = NormalizeDouble(his.MQLTick.ask - his.MQLTick.bid, 5);
   double spreadBefore = NormalizeDouble(his.MQLTickBefore.ask - his.MQLTickBefore.bid, 5);
   double spread = (spreadCurrent + spreadBefore) / 2;
   calculatedAsk = (alien.MQLTick.ask + alien.MQLTick.bid) / 2 + spread / 2;
   clculatedBid = calculatedAsk - spread;
}

// Filter Deviation point size
class MinPointsDeviation : Filter
{
public:
   MinPointsDeviation(MIN_DEVIATION& settings) : Filter() { m_enabler = settings.m_enabler; m_buyDeviation = settings.m_buyDeviation; m_sellDeviation = settings.m_sellDeviation; }

private:
   double   m_buyDeviation;
   double   m_sellDeviation;

protected:
   virtual bool VCheck(SData &his, SData &alien)
   {
      double calculatedBid, calculatedAsk;
      CalculateTick(his, alien, calculatedAsk, calculatedBid);
      
      double pointDeviationBuy   = calculatedBid - his.MQLTick.ask;
      double pointDeviationSell  = his.MQLTick.bid - calculatedAsk;
      return (pointDeviationBuy > m_buyDeviation || pointDeviationSell > m_sellDeviation);
   }
};

class MinSpreadsDeviation : Filter
{
public:
   MinSpreadsDeviation(MIN_DEVIATION& settings) : Filter() { m_enabler = settings.m_enabler; m_buyDeviation = settings.m_buyDeviation; m_sellDeviation = settings.m_sellDeviation; }

private:
   double   m_buyDeviation;
   double   m_sellDeviation;

protected:
   virtual bool VCheck(SData &his, SData &alien)
   {
      double spreadCurrent = NormalizeDouble(his.MQLTick.ask - his.MQLTick.bid, 5);
      double spreadBefore = NormalizeDouble(his.MQLTickBefore.ask - his.MQLTickBefore.bid, 5);
      double spread = (spreadCurrent + spreadBefore) / 2;
      double calculatedBid, calculatedAsk;
      CalculateTick(his, alien, calculatedAsk, calculatedBid);
      
      double koeffBuy = 0; double koeffSell = 0;
      if (NormalizeDouble(spread, 5) > 0)
      {
         koeffBuy  = (calculatedBid - his.MQLTick.ask) / spread;
         koeffSell = (his.MQLTick.bid - calculatedAsk) / spread;
      }
      return (koeffBuy > m_buyDeviation || koeffSell > m_sellDeviation);
   }
};

class FilterConfigurator
{
   FILTERS m_setting;
   
public:
   FilterConfigurator(FILTERS& setting)
   {
      m_setting.Init(setting);
   }
   
private:
   void Add(Filter* &filtes[], Filter* filter)
   {
      int index = ArrayResize(filtes, ArraySize(filtes) + 1) - 1;
      filtes[index] = filter;
   }
   
public:
   void FilterInit(Filter* &filters[])
   {
      if (m_setting.m_minPointDeviation.m_enabler)
      {
         Add(filters, new MinPointsDeviation(m_setting.m_minPointDeviation));
      }
      if (m_setting.m_minSpreadDeviation.m_enabler)
      {
         Add(filters, new MinSpreadsDeviation(m_setting.m_minSpreadDeviation));
      }
   }
};


class DeviationQuotes: Manager
{
protected:
   Filter*        m_filters[];
   TIMEOUT        m_timeOutSettings;
   bool           m_logger;
   
public:
   DeviationQuotes(FilterConfigurator* filterConfigurator, TIMEOUT& timeOutSettings, bool logger = true , bool enabler = true) : Manager(enabler)
   {
      m_logger = logger;
      filterConfigurator.FilterInit(m_filters);
      m_timeOutSettings.Init(timeOutSettings);
   }
  ~DeviationQuotes()
   {
      for (int i = 0; i < ArraySize(m_filters); i++)
      {
         if (CheckPointer(m_filters[i]) == POINTER_DYNAMIC)
         {
            delete m_filters[i]; m_filters[i] = NULL;
         }
      }
   }
protected:
   virtual void VWork(SData& datas[], int index)
   {
      Log(datas, index);
      for(int i = 0; i < ArraySize(datas); i++)
      {
         if (i == index) continue;
         
         if(CheckStopQuotes(datas[index], datas[i]))
         {
            ActionStopQuotes(datas[index], datas[i]);
         }
         else
         {
            ActionNoStopQuotes(datas[index], datas[i]);
         }
      }
   }
   virtual void ActionStopQuotes(SData& his, SData& alien)
   {
      
   }
   virtual void ActionNoStopQuotes(SData& his, SData& alien)
   {
      
   }
   
   bool CheckStopQuotes(SData &his, SData &alien)
   {
      if (BaseCheck(his, alien))
      {
         if (Filtration(his, alien))
         {
            return true;
         }
      }
      return false;
   }

private:
   bool BaseCheck(SData &his, SData &alien)
   {
      bool result = true;
      if (m_enabler)
      {
         result = result && !ExpertTimeOut(alien);
         result = result && TradeAllowed(his, alien);
         result = result && QuotesDeviation(his, alien); if (!result)   return false;
         result = result && QuotesTimeOut(his);
      }
      return result;
   }
   
   // Check quotes deviation (BID > ASK || ASK < BID)
   bool QuotesDeviation(SData &his, SData &alien)
   {
      if (!m_enabler) return false;
      return (alien.MQLTick.bid > his.MQLTick.ask) || (alien.MQLTick.ask < his.MQLTick.bid);
   }
   
   // Check timeout quotes
   bool QuotesTimeOut(SData& his)
   {
      if (!m_timeOutSettings.m_enabler)   return true;
      return his.TimeOutQuote * 0.000001 >= m_timeOutSettings.m_timeOutSeconds;
   }
   
   bool ExpertTimeOut(SData& alien)
   {
      return (TimeGMT() - alien.LastUpdateExpert) > m_timeOutSettings.m_timeOutExpertSeconds;
   }
   
   bool TradeAllowed(SData& his, SData& alien)
   {
      return (his.isTradeAllowed && alien.isTradeAllowed);
   }
   
   bool Filtration(SData &his, SData &alien)
   {
      int size = ArraySize(m_filters); int i = 0;
      bool result = true;
      while(i < size && result)
      {
         result = (result && m_filters[i].Check(his, alien));
         i++;
      }
      return result;
   }
   void Log(SData& datas[], int index)
   {
      if (!m_logger) return;
      
      string m_log = NULL;
      for(int i = 0; i < ArraySize(datas); i++)
      {
         if (i == index) continue;
         m_log += Log(datas[index], datas[i]);
      }
      Comment(m_log);
   }
protected:
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
};

