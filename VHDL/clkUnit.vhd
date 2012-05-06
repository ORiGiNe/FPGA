--===========================================================================--
--
--  S Y N T H E Z I A B L E    miniUART   C O R E
--
--  www.OpenCores.Org - January 2000
--  This core adheres to the GNU public license  
 
-- Design units   : miniUART core for the OCRP-1
--
-- File name      : clkUnit.vhd
--
-- Purpose        : Implements an miniUART device for communication purposes 
--                  between the OR1K processor and the Host computer through
--                  an RS-232 communication protocol.
--                  
-- Library        : uart_lib.vhd
--
-- Dependencies   : IEEE.Std_Logic_1164
--
--===========================================================================--
-------------------------------------------------------------------------------
-- Revision list
-- Version   Author              Date                Changes
--
-- 1.0     Ovidiu Lupas      15 January 2000         New model
-- 1.1     Ovidiu Lupas      28 May 2000     EnableRx/EnableTx ratio corrected
-- 1.2     ORiGiNe            2012          Modifications et nettoyage par ORiGiNe
--      olupas@opencores.org
-------------------------------------------------------------------------------
-- Description    : Generates the Baud clock and enable signals for RX & TX
--                  units. 
-------------------------------------------------------------------------------
-- Entity for Baud rate generator Unit - 9600 baudrate                       --
-------------------------------------------------------------------------------
library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

-------------------------------------------------------------------------------
-- Baud rate generator
-------------------------------------------------------------------------------
entity ClkUnit is
  port (
     SysClk   : in  Std_Logic;  -- System Clock
     EnableTx : out Std_Logic;  -- Control signal
     Reset    : in  Std_Logic); -- Reset input
end entity; --================== End of entity ==============================--
-------------------------------------------------------------------------------
-- Architecture for Baud rate generator Unit
-------------------------------------------------------------------------------
architecture Behaviour of ClkUnit is
  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------
  signal ClkDiv26  : Std_Logic;
  signal clkDiv10   : Std_Logic;
  signal tmpEnTX   : Std_Logic;
begin
  -----------------------------------------------------------------------------
  -- Divides the system clock of 50 MHz by 32
  -----------------------------------------------------------------------------
  DivClk26 : process(SysClk,Reset)
     constant CntOne : unsigned(4 downto 0) := "00001";
     variable Cnt26  : unsigned(5 downto 0);
  begin
     if Rising_Edge(SysClk) then
        if Reset = '0' then
           Cnt26 := "000000";
           ClkDiv26 <= '0';
        else
           Cnt26 := Cnt26 + CntOne;
           case Cnt26 is
              when "100000" =>
                  ClkDiv26 <= '1';
                  Cnt26 := "000000";                
              when others =>
                  ClkDiv26 <= '0';
           end case;
        end if;
     end if;
  end process;
  -----------------------------------------------------------------------------
  -- Provides the ClkDiv10 signal, at ~ 155 KHz
  -----------------------------------------------------------------------------
  DivClk10 : process(SysClk,Reset,Clkdiv26)
     constant CntOne : unsigned(3 downto 0) := "0001";
     variable Cnt10  : unsigned(3 downto 0);
  begin
     if Rising_Edge(SysClk) then
        if Reset = '0' then
           Cnt10 := "0000";
           clkDiv10 <= '0';
        elsif ClkDiv26 = '1' then
           Cnt10 := Cnt10 + CntOne;
        end if;
        case Cnt10 is
             when "1010" =>
                clkDiv10 <= '1';
                Cnt10 := "0000";
             when others =>
                clkDiv10 <= '0';
        end case;
     end if;
  end process;
  -----------------------------------------------------------------------------
  -- Provides the EnableTX signal, at 9.6 KHz
  -----------------------------------------------------------------------------
  DivClk16 : process(SysClk,Reset,clkDiv10)
     constant CntOne : unsigned(4 downto 0) := "00001";
     variable Cnt16  : unsigned(4 downto 0);
  begin
     if Rising_Edge(SysClk) then
        if Reset = '0' then
           Cnt16 := "00000";
           tmpEnTX <= '0';
        elsif clkDiv10 = '1' then
           Cnt16 := Cnt16 + CntOne;
        end if;
        case Cnt16 is
           when "01111" =>
                tmpEnTX <= '1';
                Cnt16 := Cnt16 + CntOne;
           when "10001" =>
                Cnt16 := "00000";
                tmpEnTX <= '0';
           when others =>
                tmpEnTX <= '0';
        end case;
     end if;
  end process;

  EnableTX <= tmpEnTX;
end Behaviour; --==================== End of architecture ===================--

