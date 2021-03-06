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
extern double Lot=1;
// Количество баров, отслеживания схождения средних
extern int narrowLenght = 5;
// Расстояние между средними для открытия позиции
extern double eps = 5;
// Трейлинг стоп
extern int TrailingStop = 300;

// Название инструмента, с которым работает советник
string SymbolName;

// Период быстрой средней
extern int fastMAPeriod = 22;
double fastMA[];
// Период медленной средней
extern int DiffPeriod = 22;
int slowMAPeriod = fastMAPeriod + DiffPeriod;
double slowMA[];
double prevFast = 0, prevSlow = 0;

void setupIndicator(int number, int draw_begin_bar, double &indicator_array[]) {
    SetIndexStyle(number, DRAW_LINE);
    SetIndexDrawBegin(number, draw_begin_bar);
    SetIndexBuffer(number, indicator_array); 
}

void drawIndicator() {

}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    SymbolName = Symbol();

    setupIndicator(0, fastMAPeriod-1, fastMA);
    setupIndicator(1, slowMAPeriod-1, slowMA);
    
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
   if (tradeIsDeprecated())
      return;

    if (OrdersTotal() > 0) {
        tryClose();
    } 

    if (OrdersTotal() > 0) {
        trailingStop();
    } 

    if (OrdersTotal() == 0) {
        tryOpen();
    }
}

bool tradeIsDeprecated() {
    return(Bars < MathMin(slowMAPeriod, fastMAPeriod) 
          || IsTradeAllowed() == false
          || Bars < narrowLenght);
}

void tryClose() {
    
    double tail[];
    ArrayResize(tail, narrowLenght);

    for(int i = 0; i < narrowLenght; ++i) {
        tail[narrowLenght - i - 1] = MathAbs(
            iMA(NULL, 0, fastMAPeriod, 0, MODE_SMA, PRICE_CLOSE, i) -
            iMA(NULL, 0, slowMAPeriod, 0, MODE_SMA, PRICE_CLOSE, i)
        );         
    }

    bool narrowed = true;

    for(int i = 1; i < narrowLenght; ++i) {
        if (tail[i] > tail[i-1]) { 
            narrowed = false; break;
        }
    }

    if (narrowed) {
        for (int i = 0; i < OrdersTotal(); i++) {                                        
            if (OrderSelect(i, SELECT_BY_POS) == true) {                                     
                OrderClose(OrderTicket(), Lot, OrderType() == 0 ? Bid : Ask, 10, Green);
            }
        }     
    }
}

void tryOpen() {
    double fast = iMA(NULL, 0, fastMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
    double slow = iMA(NULL, 0, slowMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);

    double diff = MathAbs(fast - slow);
    if (diff < eps * Point)
        return ;

    bool candidateToBuy = (fast > slow) && (prevFast < prevSlow); 
    bool candidateToSell = (fast < slow) && (prevFast > prevSlow);

    bool mayBuy = true;
    bool maySell = true;

    double stoch = iStochastic(SymbolName, 0, 7, 3, 3, MODE_EMA, 0, 0, 0);
    if (stoch > 75) mayBuy = false;
    if (stoch < 35) maySell = false;
    
    if (candidateToBuy && mayBuy)
    {
        OrderSend(SymbolName, OP_BUY, Lot, Bid, 30, Bid - StopLoss*Point, Bid + TakeProfit*Point, NULL, 0, NULL, Blue);
    }
    else if (candidateToSell && maySell)
    {
        OrderSend(SymbolName, OP_SELL, Lot, Ask, 30, Ask + StopLoss*Point, Ask - TakeProfit*Point, NULL, 0, NULL, Red);        
    }
    prevFast = fast;
    prevSlow = slow;  
    
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