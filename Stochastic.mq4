//+------------------------------------------------------------------+
//|                                                         HELL.mq4 |
//|                                                    2015, Ratuvog |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, Social Innovation Corp."
#property version   "1.00"
#property strict

// Стоп лосс в пунктах
extern int StopLoss=50;
// Тейк профит в пунктах
extern int TakeProfit=150;
// Размер лота
extern double Lot=0.1;
// Количество баров, отслеживания схождения средних
extern int TrailingStop = 300;
// Название инструмента, с которым работает советник
extern double StochMin = 20;
extern double StochMax = 80;

extern int K = 7;
extern int D = 3;
extern int S = 3;

extern int prevStoch = 10;

string SymbolName;
bool prevBuy = false;
bool prevSell = false;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("Inited");
    SymbolName = Symbol();  
    return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if (tradeIsDeprecated()) {
      Print("Deprecated");
      return;
    }

    if (OrdersTotal() > 0) {
        tryClose();
    } 

    if (OrdersTotal() > 0) {
        //trailingStop();
    } 

    if (OrdersTotal() == 0) {
        tryOpen();
    }
}

bool tradeIsDeprecated() {
    return(IsTradeAllowed() == false);
}

void tryClose() {
   double stoch = iStochastic(SymbolName, 0, K, D, S, MODE_EMA, 0, 0, 0);
   for (int i = 0; i < OrdersTotal(); i++) {                                        
        if (OrderSelect(i, SELECT_BY_POS) == true) {                                     
            int Ticket = OrderTicket();
            int Type = OrderType();
            
            if (Type == 0 && stoch > StochMax) {
               OrderClose(Ticket, Lot, OrderOpenPrice(), 30, Green);
            } else if (Type == 1 && stoch < StochMin) {
               OrderClose(Ticket, Lot, OrderOpenPrice(), 30, Green);
            }
        }
    }         
}

void tryOpen() {
    double stoch = iStochastic(SymbolName, 0, K, D, S, MODE_EMA, 0, 0, 0);
    if (stoch > StochMin && !prevBuy)
    {
        bool ok = true;
        for(int i = 1; i < prevStoch; ++i) {
            if (iStochastic(SymbolName, 0, K, D, S, MODE_EMA, 0, 0, i) > StochMin) {
                ok = false;
            }
        }
        if (ok) {
            OrderSend(SymbolName, OP_BUY, Lot, Bid, 30, Bid - StopLoss*Point,Bid + TakeProfit*Point, NULL, 0, NULL, Blue);
            prevSell = false;
            prevBuy = true;
        }
    }
    else if (stoch < StochMax && !prevSell)
    {
        bool ok = true;
        for(int i = 1; i < prevStoch; ++i) {
            if (iStochastic(SymbolName, 0, K, D, S, MODE_EMA, 0, 0, i) < StochMax) {
                 ok = false;
            }
        }
        if (ok) {
            OrderSend(SymbolName, OP_SELL, Lot, Ask, 30, Ask + StopLoss*Point, Ask - TakeProfit*Point, NULL, 0, NULL, Red);        
            prevBuy = false;
            prevSell = true;
        }
    }
     
}

void trailingStop()
{
    int Ticket, Type; 
    double Price, SL;
    
    for (int i = 0; i < OrdersTotal(); i++) {                                        
        if (OrderSelect(i, SELECT_BY_POS) == true) {                                     
            Price = OrderOpenPrice();
            SL = OrderStopLoss();
            Ticket = OrderTicket();
            Type = OrderType();
            
            if (Type == 0) {
               if (MathAbs(Bid - SL) < TrailingStop * Point) continue;
               SL = Bid - TrailingStop * Point;  
            } else if (Type == 1) {
               if (MathAbs(Ask - SL) < TrailingStop * Point) continue;
               SL = Ask + TrailingStop * Point;  
            }
            OrderModify(Ticket, Price, SL, 0, 0, Yellow);
        }
    }         
}