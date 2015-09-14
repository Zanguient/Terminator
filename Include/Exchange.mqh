//+------------------------------------------------------------------+
//|                                                     Exchange.mqh |
//|                        Copyright 2015, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"


#define ERROR_FILE_NOT_FOUND		2
#define HANDLE32	int

#import "MemMap32.dll"
   HANDLE32 MemOpen(char &path[],int size,int mode,int &err); // îòêðûâàåì/ñîçäàåì ôàéë â ïàìÿòè, ïîëó÷àåì õåíäë
   void MemClose(HANDLE32 hmem); // çàêðûâàåì ôàéë â ïàìÿòè
   HANDLE32 MemGrows(HANDLE32 hmem, char &path[],int newsize,int &err); // óâåëè÷èâàåì ðàçìåð ôàéëà â ïàìÿòè
   int MemWrite(HANDLE32 hmem,uchar &v[], int pos, int sz, int &err); // çàïèñü int(4) âåêòîðà v â ïàìÿòü ñ óêàçàííîé ïîçèöèè pos, ðàçìåðîì sz
   int MemRead(HANDLE32 hmem, uchar &v[], int pos, int sz, int &err); // ÷òåíèå âåêòîðà v ñ óêàçàííîé ïîçèöèè pos ðàçìåðîì sz
   int MemWriteStr(HANDLE32 hmem, uchar &str[], int pos, int sz, int &err); // çàïèñü ñòðîêè
   int MemReadStr(HANDLE32 hmem, uchar &str[], int pos, int &sz, int &err); // ÷òåíèå ñòðîêè âåêòîðà 
   int MemGetSize(HANDLE32 hmem, int &err);
   int MemSetSize(HANDLE32 hmem, uint size, int &err);
#import


enum FlagOpenMode
{
   modeOpen = 0,
   modeCreate = 1
};


struct SByte
{
   uchar V[1000];
};

template <typename T>
void ToByte(const T &value, uchar &bytes[])
{
   struct SVector
   {
      T V;
   };
   SVector vector;
   vector.V = value;
   SByte byte = vector;
   
   int size = sizeof(T);
   ArrayResize(bytes, size); ArrayInitialize(bytes, 0);
   ArrayCopy(bytes, byte.V, 0, 0, size);
}

template <typename T>
void ByteTo(const uchar &bytes[], T &value)
{
   struct SVector
   {
      T V;
   };
   SByte byte;
   ArrayCopy(byte.V, bytes);
   SVector vector;
   vector = byte;
   value = vector.V;
}

class FileMemory
{
private:
   string m_fileName;
   char m_fileNameChar[];
   uint m_fileSize;
   bool m_opened;
   int m_error;
   uint m_offset;
   HANDLE32 m_hMem;

public:
	FileMemory(string fileName)
	{
	   Name(fileName);
	   m_opened = false;
	   this.Seek(0);
	   LastError();
	   
      Init();
	};
   ~FileMemory()
	{
      Deinit();
	};

public: // Features
   bool     isInit()    { return (m_opened && isInstance()); }
   string   Name()  { return m_fileName; }
   int      LastError()
   {
      int error = m_error;
      m_error = 0;
      return error;
   }

protected:
   bool    isOpened()  { return m_opened; }
   bool    isInstance(){ return (m_hMem != NULL); }
   virtual void Init()
   {
	   CreateIfOpenNotFound();
   }
public:
   virtual void Deinit(bool close = true)
   {
      //if (close)
      //   this.Close();
   }
private: // Methods
   void Name(string fileName)  { m_fileName = fileName; StringToCharArray(m_fileName, m_fileNameChar); }
   void OpenOrCreate(FlagOpenMode mode)
   {
      if (!m_opened)
      {
         switch(mode)
         {
            case modeOpen:   m_hMem = MemOpen(m_fileNameChar, -1, mode, m_error); break;
            case modeCreate: m_hMem = MemOpen(m_fileNameChar, 1, mode, m_error); break;
         }
         
         if(m_hMem > 0)
         {
            m_opened = true;
            Print("[", EnumToString(mode) ,"]: true: ", m_fileName, ". handle = " + string(m_hMem));
         }
         else
         {
            m_opened = false;
            Print("[", EnumToString(mode) ,"]: false \"", m_fileName, "\"");
         }
      }
   }
   void Create()
   {
      OpenOrCreate(modeCreate);
   }
   void Open()
   {
      OpenOrCreate(modeOpen);
   }
   void Close()
   {
      if (isOpened())
      {
         if(m_hMem != NULL)
         {
            MemClose(m_hMem);
            m_hMem = NULL;
            m_opened = false;
         }
      }
   }
   void CreateIfOpenNotFound()
   {
      this.Open(); if (isOpened()) return;
      
      int error = this.LastError();
      if (error == ERROR_FILE_NOT_FOUND)
      {
         Print("[CreateIfOpenNotFound]: File not found. Try create...");
         Create();
      }
      else Print("[CreateIfOpenNotFound]: file not opened");
   }

public:
   uint Size()
   {
      return MemGetSize(m_hMem, m_error);
   }
   void Size(uint size)
   {
      MemSetSize(m_hMem, size, m_error);
   }
   uint Tell()
   {
      if (!isInit()) return 0;
      return m_offset;
   }
   void Seek(uint offset, const ENUM_FILE_POSITION origin = SEEK_SET)
   {
      if (!isInit()) return;
      
      uint size = this.Size();
   	if (origin==SEEK_SET) m_offset = offset;
   	if (origin==SEEK_CUR) m_offset += offset;
   	if (origin==SEEK_END) m_offset = size - offset;
   	
   	m_offset = (m_offset < 0)        ? 0      : m_offset;
   	m_offset = (m_offset > size)     ? size   : m_offset;
   }
   bool IsEnding()
   {
      if (!isInit()) return false;
      
      return (m_offset >= this.Size());
   }
   bool Grow(uint addSize)
   {
      if (!isInit()) return false;
      
      uint size = this.Size();
      uint newSize = size + addSize;
      
      if (newSize <= 0 ||  this.Size() > newSize)
      {
         Print("[Grow]: attempt allocate incorrect new file size. Old = ", this.Size(), ", New = ", newSize);
         return false;
      }
      Print("[Grow]: Add ", addSize, " byte");
      m_hMem = MemGrows(m_hMem, m_fileNameChar, newSize, m_error);
      if (m_hMem <= 0)
      {
         Print("[Grow]: attampt allocate new file size. error = ", m_error);
         m_opened = false;
         m_hMem = NULL;
         return false;
      }      
      return true;
   }
   
   template<typename T>
   bool Read(T &value)
   {
      if (!isInit()) return false;
      
      int size = sizeof(T);
      uchar value_char[]; ArrayResize(value_char, size); ArrayInitialize(value_char, 0);
      int result = MemRead(m_hMem, value_char, m_offset, size, m_error);
      this.Seek(result, SEEK_CUR);
      if(result < size || m_error != 0)
      {
         //Print("[Read T]: cannot read value, error code: ", m_error);
         return false;
      }
      else
      {
         ByteTo(value_char, value);
         return true;
      }
   }
   template<typename T>
   bool Read(T &array[], uint &count)
   {
      if (!isInit()) return false;
      
      ArrayResize(array, count);
      for (int i = 0; i < count; i++)
      {
         T value;
         bool result = this.Read(value);
         if (!result)
         {
            //Print("[Read T[]]: read array [", i, "]");
            ArrayResize(array, i);
            count = i;
            return true;
         }
         array[i] = value;
      }
      if (ArraySize(array) == 0) return false;
      return true;
   }
   bool ReadString(string &text, uint count = 1)
   {
      uchar text_char[]; ArrayResize(text_char, 0); ArrayInitialize(text_char, 0);
      bool result = this.Read(text_char, count);
      if (result)
      {
         text = CharArrayToString(text_char);
         return true;
      }
      return false;
   }
   
   template<typename T>
   bool Write(const T &value)
   {
      if (!isInit()) return false;
      
      uint size = sizeof(T);
      uint fileSize = this.Size();
      uint offset = this.Tell();
      if (size + offset > fileSize)
      {
         this.Grow(offset + size - fileSize);
      }
      
      uchar value_char[];
      ToByte(value, value_char);
      
      int result = MemWrite(m_hMem, value_char, m_offset, size, m_error);
      if(result != 0 || m_error != 0)
      {
         if (result == -2) // try memory grow
         {
            Print("[Write T: cannot write becouse fileSize min]");
         }
         Print("[Write T]: cannot write value, error code: ", m_error);
         return false;
      }
      else
      {
         this.Seek(size, SEEK_CUR);
         return true;
      }
   }
   template<typename T>
   bool Write(T &array[])
   {
      if (!isInit()) return false;
      
      int size = ArraySize(array);
      for (int i = 0; i < size; i++)
      {
         T value = array[i];
         bool result = this.Write(value);
         if (!result)
         {
            Print("[Write T[]]: cannot write array");
            return false;
         }

      }
      return true;
   }
   bool WriteString(string &text)
   {
      uchar text_char[]; ArrayResize(text_char, 0); ArrayInitialize(text_char, 0);
      StringToCharArray(text, text_char);
      bool result = this.Write(text_char);
      if (result)
      {
         return true;
      }
      return false;
   }
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
};
struct FileStruct // file structe
{
   SHead Head;
   SData Data[];
};


// static class for work of file "head"
class HeadWork
{
public:
   HeadWork() {}
  ~HeadWork() {}
private:
   uint Offset(EHead type = UsersOffset)
   {
      return 0 + type;
   }
public:
   
   void Init(FileMemory &file)
   {
      SHead head;
      if (Read(file, head)) // read current data
      {
         Print("[", __FUNCTION__, "]: read head. Users read file = ", head.Users);
         Print("[", __FUNCTION__, "]: add current user");
      }
      else
      {
         Print("[", __FUNCTION__, "] not read head file. try create...");
         head.Users = 0;
      }
      head.Users++;
      
      Write(file, head); // set head file
   }
   
   void Deinit(FileMemory &file)
   {
      SHead head;
      Read(file, head); // read current data
      if (head.Users > 0)  head.Users--;
      Write(file, head); // set head file
   }
   
   uint Size()
   {
      return sizeof(SHead);
   }
   
   bool Write(FileMemory &file, const SHead &head)
   {
      file.Seek(Offset());
      return file.Write(head);
   }
   
   bool Read(FileMemory &file, SHead &head)
   {
      file.Seek(Offset(), SEEK_SET);
      return file.Read(head);
   }
   // Count Users
   uint Count(FileMemory &file, const EHead type = UsersOffset)
   {
      file.Seek(Offset(type), SEEK_SET);
      
      SHead head;
      switch(type)
      {
         case UsersOffset:     file.Read(head.Users);       return head.Users;      break;
         //case TerminalsOffset: m_file.Read(m_head.Terminals);   return m_head.Terminals;  break;
         default: return 0;
      }
   }
};

class DataWork
{
private:
   uint m_maxDataArray;
public:
   DataWork() { m_maxDataArray = 100; }
  ~DataWork() {}
public:
   bool Init(FileMemory &file)
   {
      SData data[];
      uint index = 0;
      if (!Read(file, data))
      {
         Print("[", __FUNCTION__, "] not read data file. try create...");
         index = ArrayResize(data, ArraySize(data) + 1) - 1;
         return Write(file, data[index]);
      }
      return true;
      /*
      if (Read(file, data)) // read current data
      {
         
         if (!Index(file, data.Terminal, index))
         {
            Print("[", __FUNCTION__, "]: add current data terminal in last index");
            index = ArrayResize(data, ArraySize(data) + 1) - 1;
         }
         else
         {
            Print("[", __FUNCTION__, "]: current terminal exist");
         }
         
      }
      else
      {
         Print("[", __FUNCTION__, "] not read data file. try create...");
         index = ArrayResize(data, ArraySize(data) + 1) - 1;
      }
      
      //Fill(data[index]); // fill current data
      
      return Write(file, data[index]); // set file
      */
   }
   bool Deinit(FileMemory &file, const SData &data)
   {
      // delete data
      uint index = 0;
      if (Index(file, data.Terminal, index))
      {
         SData datas[];
         if (!Read(file, datas))
         {
            return false;
         }
         else
         {
            int size = ArraySize(datas);
            
            SData datasNew[]; ArrayResize(datasNew, size - 1);
            int k = 0;
            for(int i = 0; i < size; i++)
            {
               if (i != index)
               {
                  datasNew[k] = datas[i];
                  k++;
               }
            }
            // deallocate memory
            file.Size(sizeof(SHead));
            file.Seek(sizeof(SHead));
            if (!file.Write(datasNew))
            {
               Print("[", __FUNCTION__, "]: cannot write new data in file");
               return false;
            }
         }
      }
      Print("[", __FUNCTION__, "]: ok delete data");
      return true;
   }
public:
   bool Read(FileMemory &file, SData &data[])
   {
      file.Seek(Offset(DataTerminalOffset), SEEK_SET);
      
      uint count = m_maxDataArray;      
      return file.Read(data, count);
   }
   bool Read(FileMemory &file, SData &data, uint index = 0)
   {
      file.Seek(Offset(DataTerminalOffset, index), SEEK_SET);
      return file.Read(data);
   }
   bool Write(FileMemory &file, const SData &data)
   {
      uint index = 0;
      if (!Index(file, data.Terminal, index)) return false;
      
      file.Seek(Offset(DataTerminalOffset, index), SEEK_SET);
      return file.Write(data);
   }
   bool Index(FileMemory &file, const STerminal &tdata, uint &index)
   {
      SData data[];
      if (!Read(file, data))  return false;
      
      uint size = ArraySize(data);
      for(int i = 0; i < size; i++)
      {
         if (tdata.Login == data[i].Terminal.Login)
         {
            //if (ArrayCompare(tdata.Company, data[i].Terminal.Company))
            //{
            //   if (ArrayCompare(tdata.Terminal, data[i].Terminal.Terminal))
            //   {
                  index = i;
                  return true;
            //   }
            //}
         }
      }
      return false;
   }
   bool AddOrUpdate(FileMemory &file, const SData &data)
   {
      uint index = 0;
      if (!Index(file, data.Terminal, index))
      {
         SData datas[];
         if (!Read(file, datas))
         {
            Print("[", __FUNCTION__, "]: no data in file. try create...");
         }
         else Print("[", __FUNCTION__, "]: data exists in file. try add...");
         
         index = ArrayResize(datas, ArraySize(datas) + 1) - 1;
      }
      
      file.Seek(Offset(DataTerminalOffset, index), SEEK_SET);
      //return file.Write(data);
      
      // add data
      if (!file.Write(data))
      {
         Print("[", __FUNCTION__, "]: can not write data. last error:", file.LastError());
         return false;
      }
      else return true;
   }
   
   bool Size(FileMemory &file, uint &size)
   {
      SData data[];
      if (Read(file, data))
      {
         size = ArraySize(data);
         return true;
      }
      return false;
   }
private:
   uint Offset(EData type = DataTerminalOffset, uint index = 0)
   {
      return sizeof(SHead) + sizeof(SData) * index + type;
   }
};


class Notification
{
public:
   Notification(bool enable = true, uint CountLimit = 1, float ResetCountMin = 10) { m_enabler = enable; m_count = 0; m_countLimit = CountLimit; m_lastNotification = 0; m_resetCountMin = ResetCountMin; }
private:
   uint     m_countLimit;     // максимальное количество корректно отправленных сигналов
   uint     m_count;          // текущее количество отправленных сигналов
   datetime m_lastNotification;       // последнее время отправки сигнала
   float    m_resetCountMin; // количество минут, после которых сбрасывается счетчик Count - количество отправленных сигналов
   string   m_message;        // 
   bool     m_enabler;        // enable/disable signaler
protected:
   void Reset() { m_count = 0; }
   void SetLastTimeNotification()
   {
      m_lastNotification = TimeLocal();
   }
   virtual bool VSignal(string Message)
   {
      return false;
   }
   virtual void CheckResetCount()
   {
      datetime time = TimeLocal();
      datetime last = m_lastNotification;
      datetime compare = last + int(m_resetCountMin * 60);
      if (time >= compare)
      {
         Reset();
      }
   }

public:
   void Enable(bool enable)   { m_enabler = enable; }
   bool Enable()              { return m_enabler; }
   
   bool isNotification()
   {
      if (!Enable())  return false;
      CheckResetCount(); // проверяем нужно ли сбросить счетчик, если да, то сбрасываем
      return m_count < m_countLimit;
   }
   void SetMessage(string Message)
   {
      this.m_message = Message;
   }
   bool Signal()
   {
      if (isNotification()) // Проверяем можно ли запускать сигнал
      {
         if (VSignal(m_message)) // запускаем сигнал
         {
            SetLastTimeNotification(); // устанавливаем последнее время, запуска сигнала
            m_count++; // увеличиваем количество сигналов
            return true;
         }
      }
      return false;
   }
};

class ProviderSMS
{
public:
   virtual string GetStringRequest(string Message)
   {
      return Message;
   }
};

class SMSC : ProviderSMS
{
private:
   string m_URL;
   string m_login;
   string m_password;
   string m_phones;
   string m_cost;
public:
   SMSC(string login, string password, string phones, string cost = "")
   {
      this.m_URL = "http://smsc.ru/sys/send.php";
      this.m_login = login;
      this.m_password = password;
      this.m_phones = phones;
      this.m_cost = cost;
   }
   virtual string GetStringRequest(string message)
   {
      string messageGet = StringConcatenate(
         m_URL, "?",
         "login=", m_login, "&",
         "psw=", m_password, "&",
         "phones=", m_phones, "&",
         "mes=", message, "&");
      if(m_cost != "") messageGet = StringConcatenate(messageGet, "cost=", m_cost);
      return messageGet;
   }
   string GetURL()
   {
      return m_URL;
   }
};

class SMS : public Notification
{
public:
   SMS(ProviderSMS *Provider)
   {
      this.m_Provider = Provider;
   }
   ~SMS()
   {
      if (CheckPointer(m_Provider) == POINTER_DYNAMIC)
      {
         delete m_Provider; m_Provider = NULL;
      }
   }
   
private:
   ProviderSMS *m_Provider;
protected:
   virtual bool VSignal(string Message)
   {
      return Send(Message);
   }
   bool Send(string Message)
   {
      if (CheckPointer(m_Provider) == POINTER_INVALID) return false;
      
      string messageGet = m_Provider.GetStringRequest(Message);
      // отправляем GET запрос на сервер
      string cookie = NULL, headers;
      char post[], result[];
      int timeout=5000; //--- timeout менее 1000 (1 сек.) недостаточен при низкой скорости Интернета

      int res = WebRequest("GET", messageGet, cookie, NULL, timeout, post, 0, result, headers);
      if(res == -1)
      {
         Print("Ошибка в WebRequest. Код ошибки = ",GetLastError());
         //--- возможно URL отсутствует в списке, выводим сообщение о необходимости его добавления
         MessageBox("Необходимо добавить адрес '"+messageGet+"' в список разрешенных URL во вкладке 'Советники'","Ошибка",MB_ICONINFORMATION);
         
         return false;
      }
      else
      {
         return true;
      }
   }
};

class SystemAlert : Notification
{
public:
   SystemAlert(bool Enable = true, uint CountLimit = 1, float ResetCountHour = 0.5) : Notification(Enable, CountLimit, ResetCountHour) {}
  ~SystemAlert() {}
   virtual bool VSignal(string Message)
   {
      return Send(Message);
   }
   bool Send(string Message)
   {
      Alert(Message);
      return true;
   }
};

class PushNotification : Notification
{
public:
   PushNotification(bool Enable = true, uint CountLimit = 1, float ResetCountHour = 0.5) : Notification(Enable, CountLimit, ResetCountHour) {}
  ~PushNotification() {}
   virtual bool VSignal(string Message)
   {
      return Send(Message);
   }
   bool Send(string Message)
   {
      return SendNotification(Message);
   }
};

class EmailNotification : Notification
{
private:
   string m_header;
public:
   EmailNotification(bool Enable = true, uint CountLimit = 1, float ResetCountHour = 0.5) : Notification(Enable, CountLimit, ResetCountHour) { m_header = "Stop Quotes";}
  ~EmailNotification() {}
   virtual bool VSignal(string Message)
   {
      return Send(Message);
   }
   bool Send(string Message)
   {
      return SendMail(m_header, Message);
   }
};


// seald class
class Filter
{
public:
   Filter() { Enable(); }
private:
   bool   m_enable;
protected:
   virtual bool VCheck(SData &his, SData &alien)
   {
      return true;
   }
public:
   bool Check(SData &his, SData &alien)
   {
      if (!m_enable) return true;
      return VCheck(his, alien);
   }
   void Enable() { m_enable = true; }
   void Disable(){ m_enable = true; }
};

class MinPointsDeviation : Filter
{
public:
   MinPointsDeviation(double buyDeviation, double sellDeviation) { m_buyDeviation = buyDeviation; m_sellDeviation = sellDeviation; }
private:
   double m_buyDeviation;
   double m_sellDeviation;
protected:
   virtual bool VCheck(SData &his, SData &alien)
   {
      double pointDeviationBuy   = alien.MQLTick.bid - his.MQLTick.ask;
      double pointDeviationSell  = his.MQLTick.bid - alien.MQLTick.ask;
      double pointDeviation      = pointDeviationBuy > pointDeviationSell ? pointDeviationBuy : pointDeviationSell;
      return (pointDeviationBuy > m_buyDeviation || pointDeviationSell > m_sellDeviation);
   }
};

class MinSpreadsDeviation : Filter
{
public:
   MinSpreadsDeviation(double buyDeviation, double sellDeviation) { m_buyDeviation = buyDeviation; m_sellDeviation = sellDeviation; }
private:
   double m_buyDeviation;
   double m_sellDeviation;
protected:
   virtual bool VCheck(SData &his, SData &alien)
   {
      double spreadCurrent = NormalizeDouble(his.MQLTick.ask - his.MQLTick.bid, 5);
      double spreadBefore = NormalizeDouble(his.MQLTickBefore.ask - his.MQLTickBefore.bid, 5);
      double spread = (spreadCurrent + spreadBefore) / 2;
      double koeffBuy = 0; double koeffSell = 0;
      if (NormalizeDouble(spread, 5) > 0)
      {
         koeffBuy = (alien.MQLTick.bid - his.MQLTick.ask) / spread;
         koeffSell= (his.MQLTick.bid - alien.MQLTick.ask) / spread;
      }
      return (koeffBuy > m_buyDeviation || koeffSell > m_sellDeviation);
   }
};

class Checker
{
private:
   Filter *m_filters[];
public:
   Checker() {}
   Checker(Filter* filter)    { AddFilter(filter); }
   Checker(Filter* &filters[]) { for (int i = 0; i < ArraySize(filters); i++)  AddFilter(filters[i]); }
  
  ~Checker()
   {
      for (int i = 0; i < ArraySize(m_filters); i++)
      {
         if (CheckPointer(m_filters[i]) == POINTER_DYNAMIC)
         {
            delete m_filters[i]; m_filters[i] = NULL;
         }
      }
   }
   
private:
   bool FiltersApply(SData &his, SData &alien)
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
protected:
   // defenition logic deviation situation
   virtual bool BaseCheck(SData &his, SData &alien)
   {
      return true;
   }   
public:
   void AddFilter(Filter *filter)
   {
      int index = ArrayResize(m_filters, ArraySize(m_filters) + 1) - 1;
      m_filters[index] = filter;
   }
   bool Check(SData &his, SData &alien)
   {
      if (BaseCheck(his, alien))
      {
         return FiltersApply(his, alien);
      }
      return false;
   }
};

class StopQuotesChecker : Checker
{
private:
   bool   m_timeOut;
   double m_timeOutSeconds;
public:
   StopQuotesChecker()                                            : Checker()          { m_timeOut = true; m_timeOutSeconds = 30; }
   StopQuotesChecker(double timeOutSeconds)                       : Checker()          { m_timeOut = true; m_timeOutSeconds = timeOutSeconds; }
   StopQuotesChecker(double timeOutSeconds, Filter* filter)       : Checker(filter)    { m_timeOut = true; m_timeOutSeconds = timeOutSeconds; }
   StopQuotesChecker(double timeOutSeconds, Filter* &filters[])   : Checker(filters)   { m_timeOut = true; m_timeOutSeconds = timeOutSeconds; }
protected:
   virtual bool BaseCheck(SData &his, SData &alien)
   {
      bool result = true;
      if (m_timeOut)
      {
         result = result && QuotesTimeOut(his);
      }
      //result = result && QuotesDifferents(his, alien);
      return result;
   }
   bool QuotesDifferents(SData &his, SData &alien)
   {
      return (alien.MQLTick.bid > his.MQLTick.ask) || (alien.MQLTick.ask < his.MQLTick.bid);
   }
   bool QuotesTimeOut(SData &his)
   {
      return his.TimeOutQuote * 0.000001 >= m_timeOutSeconds;
   }
public:
   void EnableTimeOut(bool timeOut = true)
   {
      m_timeOut = timeOut;
   }
};

class Monitor
{
private:
   string         m_fileName;
   string         m_symbolNameInTerminal;
   FileMemory*    m_file;
   HeadWork       m_head;
   DataWork       m_data;
   
public:
   Monitor(string fileName, string symbolNameInTerminal)
   {
      m_fileName = fileName;
      m_symbolNameInTerminal = symbolNameInTerminal;
      
      Init();
   }
  ~Monitor()
   {
      Deinit();
   }
private:
   void Init()
   {
      m_file = new FileMemory(m_fileName);
      m_head.Init(m_file);
      m_data.Init(m_file);
   }
   void Deinit()
   {
      m_head.Deinit(m_file);
      
      SData data; Fill(data);
      m_data.Deinit(m_file, data);
      
      SHead head; m_head.Read(m_file, head);
      
      if (CheckPointer(m_file) == POINTER_DYNAMIC)
      {
         if (head.Users <= 0) m_file.Deinit(true);
         delete m_file; m_file = NULL;
      }
      /*
      if (CheckPointer(m_checker) == POINTER_DYNAMIC)
      {
         delete m_checker; m_checker = NULL;
      }
      */
   }
   void Fill(STerminal &data)
   {
      StringToCharArray(TerminalName(), data.Terminal);
      data.Login = AccountNumber();
      StringToCharArray(AccountCompany(), data.Company);
   }
   void Fill(SData &data)
   {
      Fill(data.Terminal);
      SymbolInfoTick(m_symbolNameInTerminal, data.MQLTick);
      StringToCharArray(m_symbolNameInTerminal, data.TSymbol);
   }
   void Data(SData &data[])
   {
      m_data.Read(m_file, data);
   }
   bool isQuotesUpdate(SData &his, SData &alien)
   {
      return (
         NormalizeDouble(his.MQLTick.ask, 5) != NormalizeDouble(alien.MQLTick.ask, 5) ||
         NormalizeDouble(his.MQLTick.bid, 5) != NormalizeDouble(alien.MQLTick.bid, 5));
   }
public:
   void Update(SData &datas[])
   {
      SData data; Fill(data);
      if (m_data.Read(m_file, datas))
      {
         int index;
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
   }
};

class Customer
{
private:
   Checker*       m_checker;
   Notification*  m_notifications[];
   Monitor*       m_monitors[];
   string         m_prefix;
public:
   Customer(Checker *checker)
   {
      m_prefix = "Local\"";
      m_checker = checker;
   }
  ~Customer()
   {
      int i = 0;
      for (i = 0; i < ArraySize(m_notifications); i++)
      {
         if (CheckPointer(m_notifications[i]) == POINTER_DYNAMIC)
         {
            delete m_notifications[i]; m_notifications[i] = NULL;
         }
      }
      if (CheckPointer(m_checker) == POINTER_DYNAMIC)
      {
         delete m_checker; m_checker = NULL;
      }
      for (i = 0; i < ArraySize(m_monitors); i++)
      {
         if (CheckPointer(m_monitors[i]) == POINTER_DYNAMIC)
         {
            delete m_monitors[i]; m_monitors[i] = NULL;
         }
      }
   }
protected:
   // Update information Data file for each 
   virtual void Work(SData &datas[], string& mLog)
   {
      uint current = 0;
      int i = 0;
      int size = ArraySize(datas);
      for (i = 0; i < size; i++)
      {
         if (datas[i].Terminal.Login == AccountNumber())
         {
            current = i; break;
         }
      }
      
      for(i = 0; i < size; i++)
      {
         if (i == current) continue;
         
         if (m_checker.Check(datas[current], datas[i]))
         {
            for(int j = 0; j < ArraySize(m_notifications); j++)
            {
               if (m_notifications[j].isNotification())
               {
                  string text = Log(datas[current], datas[i]);
                  Print(text);
                  m_notifications[j].SetMessage(text);
                  m_notifications[j].Signal();
               }
            }
        }
         mLog += Log(datas[current], datas[i]) + "\n\n";
      }
      //Comment(mLog);
   }
public:
   void AddMonitor(string symbolMemory, string symbolTerminal)
   {
      int index = ArrayResize(m_monitors, ArraySize(m_monitors) + 1) - 1;
      m_monitors[index] = new Monitor(m_prefix + symbolMemory, symbolTerminal);
   }
   void AddNotification(Notification *notification)
   {
      int index = ArrayResize(m_notifications, ArraySize(m_notifications) + 1) - 1;
      m_notifications[index] = notification;
   }
   // Update information Data file for each monitors
   void UpdateMonitors(string& mLog)
   {
      int size = ArraySize(m_monitors);
      for (int i = 0; i < size; i++)
      {
         SData data[];
         m_monitors[i].Update(data);
         Work(data, mLog);
      }
   }
   
protected:
   virtual string StopLog(SData &his, SData &alien)
   {
      
      double pointBuy  = alien.MQLTick.bid - his.MQLTick.ask;
      double pointSell = his.MQLTick.bid - alien.MQLTick.ask;
      double KBuy  = (alien.MQLTick.bid - his.MQLTick.ask) / (his.MQLTick.ask - his.MQLTick.bid);// m_checker.KBuy (alien.MQLTick.bid, his.MQLTick.ask, his.MQLTick.bid);
      double KSell = (his.MQLTick.ask - alien.MQLTick.bid) / (his.MQLTick.ask - his.MQLTick.bid);//m_checker.KSell(alien.MQLTick.ask, his.MQLTick.ask, his.MQLTick.bid);
      double kDiff = KBuy > KSell ? KBuy : KSell;
      int OP = KBuy > KSell ? OP_BUY : OP_SELL;
      //m_checker.Check(KBuy, KSell, kDiff, OP);
      double points;
      string textOP = NULL;
      if (OP == OP_BUY)
      {
         points = pointBuy;
         textOP = "BUY";
      }
      else
      {
         points = pointSell;
         textOP = "SELL";
      }
      
      return StringConcatenate(
         "STOP ", CharArrayToString(his.TSymbol), "\n",
         textOP, ": ", "+ ", DoubleToString(kDiff, 2), " sp. ( ", DoubleToString(points, 5), " p. )", "\n",
         CharArrayToString(alien.Terminal.Company)
      );
      
      return NULL;
   }
   virtual string Log(SData &his, SData &alien)
   {
      string company = CharArrayToString(alien.Terminal.Company);
      int login = alien.Terminal.Login;
      
      double pointBuy  = alien.MQLTick.bid - his.MQLTick.ask;
      double pointSell = his.MQLTick.bid - alien.MQLTick.ask;
      
      //double KBuy  = m_checker.KBuy (alien.MQLTick.bid, his.MQLTick.ask, his.MQLTick.bid);
      //double KSell = m_checker.KSell(alien.MQLTick.ask, his.MQLTick.ask, his.MQLTick.bid);
      double kDiff;
      int OP;
      //bool status = m_checker.Check(KBuy, KSell, kDiff, OP);
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
         "  Spread avg        ", DoubleToString(spreadAverageAlien, 5), "    |     ", DoubleToString(spreadAverage, 5), "    \n",
         "-------------------------------------------------------------------", "\n",
         "  Buy:                " , DoubleToString(pointBuy / spreadAverage,  2), " sp.    |   ", DoubleToString(pointBuy,  5), " pt.", "\n",
         "  Sell:                 ", DoubleToString(pointSell / spreadAverage, 2), " sp.    |   ", DoubleToString(pointSell, 5), " pt.", "\n",
         //"     Stop quotes: ", string(status), "\n",
         "-------------------------------------------------------------------", "\n"
      );
      
      return NULL;
   }
};