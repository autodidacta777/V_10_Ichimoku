//+------------------------------------------------------------------+
//|      EA Ichimoku con trailing dinámico y reentrada en Tenkan     |
//+------------------------------------------------------------------+
#property strict

input double Lote = 0.01;
input double SL_USD = 1.0;
input double TP_USD = 8.0;
input double TrailingStart = 3.0;
input double TrailingStep = 1.0;
input int    MaxTrades = 8;

//--------------------------------------------------------------------
// Calcular valor pip aproximado
double ValorPip()
{
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   if(tickValue <= 0) tickValue = 0.0001;
   return tickValue * Lote * 100000 / 10.0;
}

//--------------------------------------------------------------------
// Contar trades del símbolo actual
int ContarOperaciones()
{
   int c = 0;
   for(int i=0; i<OrdersTotal(); i++)
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderSymbol() == Symbol())
            c++;
   return c;
}

//--------------------------------------------------------------------
void OnTick()
{
   if(ContarOperaciones() >= MaxTrades) return;

   //--- valores Ichimoku
   double tenkan0 = iIchimoku(NULL,0,9,26,52,MODE_TENKANSEN,0);
   double kijun0  = iIchimoku(NULL,0,9,26,52,MODE_KIJUNSEN,0);
   double tenkan1 = iIchimoku(NULL,0,9,26,52,MODE_TENKANSEN,1);
   double kijun1  = iIchimoku(NULL,0,9,26,52,MODE_KIJUNSEN,1);

   bool cruceAlcista = (tenkan1 < kijun1 && tenkan0 > kijun0);
   bool cruceBajista = (tenkan1 > kijun1 && tenkan0 < kijun0);

   //--- Precio y pip conversion
   double pipValue = ValorPip();
   double sl_pips = SL_USD / pipValue / Point;
   double tp_pips = TP_USD / pipValue / Point;

   //-----------------------------------------------------------------
   // Señal principal: cruce Tenkan-Kijun
   //-----------------------------------------------------------------
   if(cruceAlcista)
   {
      double sl = Bid - sl_pips * Point;
      double tp = Bid + tp_pips * Point;
      OrderSend(Symbol(), OP_BUY, Lote, Ask, 3, sl, tp, "Ichimoku Buy", 12345, 0, clrGreen);
   }
   if(cruceBajista)
   {
      double sl = Ask + sl_pips * Point;
      double tp = Ask - tp_pips * Point;
      OrderSend(Symbol(), OP_SELL, Lote, Bid, 3, sl, tp, "Ichimoku Sell", 12346, 0, clrRed);
   }

   //-----------------------------------------------------------------
   // Reentrada: rebote del precio en Tenkan-Sen
   //-----------------------------------------------------------------
   double close1 = iClose(NULL,0,1); // cierre anterior
   double open0  = iOpen(NULL,0,0);

   // Reentrada de compra
   if(close1 > tenkan1 && Bid <= tenkan0 && tenkan0 > kijun0)
   {
      double sl = Bid - sl_pips * Point;
      double tp = Bid + tp_pips * Point;
      OrderSend(Symbol(), OP_BUY, Lote, Ask, 3, sl, tp, "Reentry Tenkan Buy", 22345, 0, clrBlue);
   }

   // Reentrada de venta
   if(close1 < tenkan1 && Ask >= tenkan0 && tenkan0 < kijun0)
   {
      double sl = Ask + sl_pips * Point;
      double tp = Ask - tp_pips * Point;
      OrderSend(Symbol(), OP_SELL, Lote, Bid, 3, sl, tp, "Reentry Tenkan Sell", 22346, 0, clrOrange);
   }

   //-----------------------------------------------------------------
   // Trailing dinámico
   //-----------------------------------------------------------------
   for(int i=0; i<OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol()!=Symbol()) continue;
         double profitUSD = OrderProfit() + OrderSwap() + OrderCommission();

         if(profitUSD >= TrailingStart)
         {
            double pipValue2 = MarketInfo(Symbol(), MODE_TICKVALUE);
            if(pipValue2<=0) pipValue2=0.0001;
            double newStop;

            if(OrderType()==OP_BUY)
            {
               newStop = Bid - (TrailingStep / pipValue2) * Point * 10;
               if(newStop > OrderStopLoss())
                  OrderModify(OrderTicket(), OrderOpenPrice(), newStop, OrderTakeProfit(), 0, clrBlue);
            }
            if(OrderType()==OP_SELL)
            {
               newStop = Ask + (TrailingStep / pipValue2) * Point * 10;
               if(newStop < OrderStopLoss() || OrderStopLoss()==0)
                  OrderModify(OrderTicket(), OrderOpenPrice(), newStop, OrderTakeProfit(), 0, clrBlue);
            }
         }
      }
   }
}
