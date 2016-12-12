--
-- calendar
-- 
-- @idea: 		thefarm
-- @author:    	MCB
-- @version:    v1.0
-- @date:       2016-17-10
-- 
--
calendar = {};
calendar.modDir = g_currentModDirectory;
calendar.hudOverlay = createImageOverlay(Utils.getFilename("overlay.dds", g_currentModDirectory));
calendar.hudPosSize = {x=0.319, y=0.549, w=0.36265, h=0.138};
addModEventListener(calendar);

function calendar.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(SowingMachine, specializations);
end;

function calendar:loadMap(name)		
	--days of the week
	self.days = {};
	self.days[6] = "Sun";
	self.days[0] = "Mon";
	self.days[1] = "Tue";
	self.days[2] = "Wed";
	self.days[3] = "Thu";
	self.days[4] = "Fri";
	self.days[5] = "Sat";
	
	--low temps
	self.lowTemps = {}
	self.lowTemps["Jan"] = -11;          
	self.lowTemps["Feb"] = -7;
	self.lowTemps["Mar"] = -1;
	self.lowTemps["Apr"] = 2;
	self.lowTemps["May"] = 11;
	self.lowTemps["Jun"] = 17;
	self.lowTemps["Jul"] = 19; 
	self.lowTemps["Aug"] = 18;
	self.lowTemps["Sep"] = 13;
	self.lowTemps["Oct"] = 6;
	self.lowTemps["Nov"] = 2;
	self.lowTemps["Dec"] = -3;	
	
	--high temps
	self.highTemps = {}           
	self.highTemps["Jan"] = 3;
	self.highTemps["Feb"] = 4;
	self.highTemps["Mar"] = 9;
	self.highTemps["Apr"] = 14;
	self.highTemps["May"] = 21;
	self.highTemps["Jun"] = 26;
	self.highTemps["Jul"] = 28;
	self.highTemps["Aug"] = 27;
	self.highTemps["Sep"] = 23;
	self.highTemps["Oct"] = 16;
	self.highTemps["Nov"] = 12;
	self.highTemps["Dec"] = 6;	
	
	-- date variables
	self.totalDays = g_currentMission.environment.currentDay; 
	self.dayOfWeek = nil; 
	self.day = nil; 
	self.month = nil; 	
	self.year = nil; 
	self.initial_year = 2013; 
	self.leap = false; -- leap year		
	self.callChangeDay = true;
	self.dayCompare = nil;
	
	--planting season variables
	self.seedWarn = nil;
	self.currentSeedWarningFruit = nil;
	
	--growth variables
	self.fruitData = {};
	
	--load variables
	self.isLoaded = false;
	self.newGame = false;
	
	g_currentMission.environment.calendar = self;	
end;

function calendar:deleteMap()
	--print("<----- deleteMap");
	self.days = nil;
	self.lowTemps = nil;
	self.highTemps = nil;
	self.fruitData = nil;
	self.isLoaded = false;	
end;
	
function calendar:loadFromAttributes()	
	local savegamePath = g_currentMission.missionInfo.savegameDirectory .. "/calendar.xml";
	local xmlFile = loadXMLFile("tempCalendar", savegamePath);
	local key = "temperatures";
	
	for i = 1, table.getn(g_currentMission.environment.weatherTemperaturesDay)
	do
		local dayTemp = getXMLInt(xmlFile, key.."#dayTemp"..tostring(i));
		if dayTemp ~= nil then
			g_currentMission.environment.weatherTemperaturesDay[i] = dayTemp;
		end;
		--print("<------- dayTemp: ", dayTemp);
	end;
	
	for i = 1, table.getn(g_currentMission.environment.weatherTemperaturesNight)
	do
		local nightTemp = getXMLInt(xmlFile, key.."#nightTemp"..tostring(i));
		if nightTemp ~= nil then
			g_currentMission.environment.weatherTemperaturesNight[i] = nightTemp;
		end;
		--print("<------- dayTemp: ", dayTemp);
	end;		
	print("<----- xml loaded");		
	delete(xmlFile);
end;

function calendar:getSaveAttributes()
	local savegame = self.savegames[self.selectedIndex];
	if savegame ~= nil then
		local key = "temperatures";
		local xmlFile = createXMLFile("tempCalendar", savegame.savegameDirectory .. "/calendar.xml", key);
		local dayTemperatures = g_currentMission.environment.weatherTemperaturesDay; 
		local nightTemperatures = g_currentMission.environment.weatherTemperaturesNight; 
				
		for k , v in pairs(dayTemperatures) 
		do			
			setXMLInt(xmlFile, key .. "#dayTemp"..tostring(k), (v));
		end;
		for k , v in pairs(nightTemperatures) 
		do			
			setXMLInt(xmlFile, key .. "#nightTemp"..tostring(k), (v));
		end;			
		
		print("<----- save attributes");		
		saveXMLFile(xmlFile);
		delete(xmlFile);
	end;
end;
CareerScreen.saveSelectedGame = Utils.appendedFunction(CareerScreen.saveSelectedGame, calendar.getSaveAttributes);

function calendar:mouseEvent(posX, posY, isDown, isUp, button)
end;

function calendar:keyEvent(unicode, sym, modifier, isDown)
end;

function calendar:update(dt)	
	local g = g_currentMission.environment;
	
	if g.currentDay ~= nil then
		self.totalDays = g.currentDay;
	end;	
	
	if self.callChangeDay == true or self.dayCompare ~= self.totalDays then
		self:changeDay();
		self.dayCompare = self.totalDays;		
		self.callChangeDay = false;
	end;
	
	if self.isLoaded == false then
		local savegamePath = g_currentMission.missionInfo.savegameDirectory .. "/calendar.xml";
		if fileExists(savegamePath) then			
			self:loadFromAttributes();
		else
			self.newGame = true;
			self:adjustWeather();
		end;
		self.isLoaded = true;
	end;	
end;

function calendar:draw()		
	--render date on the clock
	setTextColor(1,1,1,1);
	renderText(0.831, 0.9525, 0.02, self.month.." "..string.format("%.0f", self.day)..", "..string.format("%.0f", self.year));
	setTextColor(0,0,0,1);
	renderText(0.831, 0.954, 0.02, self.month.." "..string.format("%.0f", self.day)..", "..string.format("%.0f", self.year));	
	
	--render seedWarn if crop is out of season
	if self.seedWarn == true then
		renderOverlay(calendar.hudOverlay, calendar.hudPosSize.x, calendar.hudPosSize.y, calendar.hudPosSize.w, calendar.hudPosSize.h);
		setTextAlignment(RenderText.ALIGN_Left);
		setTextColor(0.94,0.8,0,1);
		renderText(calendar.hudPosSize.x + 0.02, calendar.hudPosSize.y + 0.0575, 0.02, "It is not planting season for "..self.currentSeedWarningFruit.."!");	
	end;
end;

function calendar:changeDay()
	local tempTotalDays = self.totalDays;
	local dayOfYear = nil;
	local addyears = 0;
	
	self.dayOfWeek = self.days[tempTotalDays % 7];
	if self.totalDays > 365 then
		while (tempTotalDays > 365)
		do
		   addyears = addyears + 1;
		   tempTotalDays = tempTotalDays - 365;
		end;
			
		self.year = self.initial_year + addyears;
	else
		self.year = self.initial_year;
	end;
	--TODO if year % 100 == 0, if year % 400 == 0 then leap == true else false
	if self.year % 4 == 0 then
		self.leap = true;
	else
		self.leap = false;
	end;
	if self.leap == false then
		if tempTotalDays % 366 == 0 then     
			dayOfYear = 1;
		elseif tempTotalDays % 365 == 0 then
			dayOfYear = 365;
		else
		   dayOfYear = tempTotalDays % 365;
		end;

		 if dayOfYear > 0 and dayOfYear < 32 then
			self.month = "Jan";
			self.day = dayOfYear;
		 elseif dayOfYear > 31 and dayOfYear < 60 then
			self.month = "Feb";
			self.day = dayOfYear - 31;
		 elseif dayOfYear > 59 and dayOfYear < 91 then
			self.month = "Mar";
			self.day = dayOfYear - 59;
		 elseif dayOfYear > 90 and dayOfYear < 121 then
			self.month = "Apr";
			self.day = dayOfYear - 90;
		 elseif dayOfYear > 120 and dayOfYear < 152 then
			self.month = "May";
			self.day = dayOfYear - 120;
		 elseif dayOfYear > 151 and dayOfYear < 182 then
			self.month = "Jun";
			self.day = dayOfYear - 151;
		 elseif dayOfYear > 181 and dayOfYear < 213 then
			self.month = "Jul";
			self.day = dayOfYear - 181;
		 elseif dayOfYear > 212 and dayOfYear < 244 then
			self.month = "Aug";
			self.day = dayOfYear - 212;
		 elseif dayOfYear > 243 and dayOfYear < 274 then
			self.month = "Sep";
			self.day = dayOfYear - 243;
		 elseif dayOfYear > 273 and dayOfYear < 305 then
			self.month = "Oct";
			self.day = dayOfYear - 273;
		 elseif dayOfYear > 304 and dayOfYear < 335 then
			self.month = "Nov";
			self.day = dayOfYear - 304;
		 elseif dayOfYear > 334 and dayOfYear < 366 then
			self.month = "Dec"; 
			self.day = dayOfYear - 334;
		 end;
	else
		if tempTotalDays % 367 == 0 then     
			dayOfYear = 1;
		elseif tempTotalDays % 366 == 0 then
			dayOfYear = 366;
		else
		   dayOfYear = tempTotalDays % 366;
		end;

		 if dayOfYear > 0 and dayOfYear < 32 then
			self.month = "Jan";
			self.day = dayOfYear;
		 elseif dayOfYear > 31 and dayOfYear < 61 then
			self.month = "Feb";
			self.day = dayOfYear - 31;
		 elseif dayOfYear > 60 and dayOfYear < 92 then
			self.month = "Mar";
			self.day = dayOfYear - 60;
		 elseif dayOfYear > 91 and dayOfYear < 122 then
			self.month = "Apr";
			self.day = dayOfYear - 91;
		 elseif dayOfYear > 121 and dayOfYear < 153 then
			self.month = "May";
			self.day = dayOfYear - 121;
		 elseif dayOfYear > 152 and dayOfYear < 183 then
			self.month = "Jun";
			self.day = dayOfYear - 152;
		 elseif dayOfYear > 182 and dayOfYear < 214 then
			self.month = "Jul";
			self.day = dayOfYear - 182;
		 elseif dayOfYear > 213 and dayOfYear < 245 then
			self.month = "Aug";
			self.day = dayOfYear - 213;
		 elseif dayOfYear > 244 and dayOfYear < 275 then
			self.month = "Sep";
			self.day = dayOfYear - 244;
		 elseif dayOfYear > 274 and dayOfYear < 306 then
			self.month = "Oct";
			self.day = dayOfYear - 274;
		 elseif dayOfYear > 305 and dayOfYear < 336 then
			self.month = "Nov";
			self.day = dayOfYear - 305;
		 elseif dayOfYear > 335 and dayOfYear < 367 then
			self.month = "Dec"; 
			self.day = dayOfYear - 335;
		 end;
	end;
	
	if self.callChangeDay ~= true then
		self:adjustWeather();
	end;
	
	if (self.month == "Jan" and self.day == 1) or (self.month == "Mar" and self.day == 1)then
		self:fruitGrowth()
	end;
	--print("<----- changeDay");
	--print("<---- cself.totalDays: ", self.totalDays);
	--print("<---- cself.dayOfWeek: ", self.dayOfWeek);
	--print("<----- cself.day: ", (self.day));
	--print("<----- cself.day_string.format: ", string.format("%.0f", self.day));	
	--print("<----- cself.day_type: ", type(self.day));
	--print("<----- cself.month: ", self.month);
	--print("<----- cdayOfYear: ", dayOfYear);	
	--print("<----- cself.year_string.format: ", string.format("%.0f", self.year));
end;

function calendar:fruitGrowth()
	-- Disable growth for the winter
	if self.month == "Jan" or self.month =="Feb" then
		for i = 1, FruitUtil.NUM_FRUITTYPES do
			local fruitDesc = FruitUtil.fruitIndexToDesc[i]
			local fruitLayer = g_currentMission.fruits[fruitDesc.index];
			if fruitLayer ~= nil and fruitLayer.id ~= 0 and fruitDesc.minHarvestingGrowthState >= 0 then
				-- Disable growth
				setEnableGrowth(fruitLayer.id, false);
			end;
		end;
	else
		for i = 1, FruitUtil.NUM_FRUITTYPES do
			local fruitDesc = FruitUtil.fruitIndexToDesc[i]
			local fruitLayer = g_currentMission.fruits[fruitDesc.index];
			if fruitLayer ~= nil and fruitLayer.id ~= 0 and fruitDesc.minHarvestingGrowthState >= 0 then
				-- Enable growth
				setEnableGrowth(fruitLayer.id, true);
			end;
		end;
	end;
end;

function calendar:fruitYield()
	--TODO
end;

function calendar:adjustWeather()
	local dayTemp = g_currentMission.environment.weatherTemperaturesDay;
	local nightTemp = g_currentMission.environment.weatherTemperaturesNight;
	local newForecastDay = table.getn(g_currentMission.environment.weatherTemperaturesDay)
	print("<------- self.newGame: ", self.newGame);
	--if new game, convert all temps	
	if self.newGame == true then				
		for i =1, table.getn(dayTemp)
		do		
			while (dayTemp[i] >= self.highTemps[self.month])
			do
				dayTemp[i] = math.random(self.lowTemps[self.month], self.highTemps[self.month]);				
			end;			
			g_currentMission.environment.weatherTemperaturesDay[i] = dayTemp[i];				
			
			if nightTemp[i] <= self.lowTemps[self.month] or nightTemp[i] >= dayTemp[i] then
				nightTemp[i] = math.random(self.lowTemps[self.month], dayTemp[i]);		
			end;
			g_currentMission.environment.weatherTemperaturesNight[i] = nightTemp[i];
		end;		
	else	
		--convert new forecast temps
		print("<------ day");		
		while (dayTemp[newForecastDay] >= self.highTemps[self.month])
		do
			dayTemp[newForecastDay] = math.random(self.lowTemps[self.month], self.highTemps[self.month]);				
		end;			
		g_currentMission.environment.weatherTemperaturesDay[newForecastDay] = dayTemp[newForecastDay];				
		print("<------ night");
		if nightTemp[newForecastDay] <= self.lowTemps[self.month] or nightTemp[newForecastDay] >= dayTemp[newForecastDay] then
			nightTemp[newForecastDay] = math.random(self.lowTemps[self.month], dayTemp[newForecastDay]);		
		end;
		g_currentMission.environment.weatherTemperaturesNight[newForecastDay] = nightTemp[newForecastDay];			
	end;
	self.newGame = false;
	--make sure it doesn't snow when it is too warm (hail looks too much like snow in this game so I treat as such)
	--TODO: make sure it snows when it is cold enough
	print("<------ rains");
	local rain = g_currentMission.environment.rains;	
	for i = 1, table.getn(rain)
	do
		local weatherDayIndex = rain[i].startDay - self.totalDays;
		if dayTemp[weatherDayIndex] ~= nil and dayTemp[weatherDayIndex] >= 4 or nightTemp[weatherDayIndex] ~= nil and nightTemp[weatherDayIndex] >= 4 then
			if rain[i].rainTypeId == "hail" then
				rain[i].rainTypeId = "rain";
			end;
		end;
	end;
	
	
end;

--for appending variable 'tempFillLevel' to SowingMachine:load()
function calendar:tempFillLevel()
	self.tempFillLevel = nil;
end;

--for appending seedWarning to SowingMachine:update()
function calendar:seedWarning()	
	--self = SowingMachine	
	--if in season, seedWarn is false else true	
	local selectedSeed = FruitUtil.fruitIndexToDesc[self.seeds[self.currentSeed]].name;
	local seedWarn = nil;
	local currentSeedWarningFruit = nil;
	local month = g_currentMission.environment.calendar.month;
	if self:getIsActiveForInput() then			
		if month == "Jan" then
			seedWarn = true;
			currentSeedWarningFruit = selectedSeed;		
		elseif month == "Feb" then
			seedWarn = true;
			currentSeedWarningFruit = selectedSeed;
		elseif month == "Mar" then
			if selectedSeed == "hops" or selectedSeed == "cranberry" or selectedSeed == "sorghum" or selectedSeed == "grass" then			
				seedWarn = false;				
			else	
				seedWarn = true;
				currentSeedWarningFruit = selectedSeed;
			end;
		elseif month == "Apr" then			
			seedWarn = false;			
		elseif month == "May" then
			if selectedSeed == "cranberry" then			
				seedWarn = true;
				currentSeedWarningFruit = selectedSeed;
			else	
				seedWarn = false;						
			end;
		elseif month == "Jun" then
			if selectedSeed == "cranberry" or selectedSeed == "wheat" or selectedSeed == "hops" or selectedSeed == "rape" or selectedSeed == "sugarBeet" then			
				seedWarn = true;
				currentSeedWarningFruit = selectedSeed;
			else	
				seedWarn = false;						
			end;
		elseif month == "Jul" then
			if selectedSeed == "sorghum" or selectedSeed == "grass" then			
				seedWarn = false;				
			else	
				seedWarn = true;
				currentSeedWarningFruit = selectedSeed;
			end;
		elseif month == "Aug" then
			if selectedSeed == "rape" or selectedSeed == "grass" then			
				seedWarn = false;				
			else	
				seedWarn = true;
				currentSeedWarningFruit = selectedSeed;
			end;
		elseif month == "Sep" then
			if selectedSeed == "rape" or selectedSeed == "wheat" or selectedSeed == "barley" or selectedSeed == "grass"then			
				seedWarn = false;				
			else	
				seedWarn = true;
				currentSeedWarningFruit = selectedSeed;
			end;
		elseif month == "Oct" then
			if selectedSeed == "wheat" or selectedSeed == "barley" or selectedSeed == "grass" then			
				seedWarn = false;				
			else	
				seedWarn = true;
				currentSeedWarningFruit = selectedSeed;
			end;
		elseif month == "Nov" then
			if selectedSeed == "wheat" or selectedSeed == "barley" or selectedSeed == "grass" then			
				seedWarn = false;				
			else	
				seedWarn = true;
				currentSeedWarningFruit = selectedSeed;
			end;
		else --if Dec
			seedWarn = true;
			currentSeedWarningFruit = selectedSeed;
		end;			
		
		if InputBinding.hasEvent(InputBinding.IMPLEMENT_EXTRA3) then
			print("<------ crop: ", selectedSeed);
			print("<------ sow_seedWarn: ", seedWarn);
			
			self.tempFillLevel = self.fillLevel;
			print("self.tempFillLevel: ", self.tempFillLevel);
			
			if seedWarn == true then
				self.fillLevel = 0;
			else
				self.fillLevel = self.tempFillLevel;
			end;
			--return self.fillLevel;
		end;
	else		
		seedWarn = false;
	end;
	g_currentMission.environment.calendar.seedWarn = seedWarn;
	g_currentMission.environment.calendar.currentSeedWarningFruit = currentSeedWarningFruit;
end;

--for overwriting SowingMachine:getFillLevel() with disableSeeding
function calendar:disableSeeding(superFunc, fillType)	
	local seedWarn = g_currentMission.environment.calendar.seedWarn;	
	if seedWarn == true then --or (InputBinding.hasEvent(InputBinding.IMPLEMENT_EXTRA3) and seedWarn == true) then
        self.fillLevel = 0;
	else
		local fillLevel = self.fillLevel;
		print("<------ fillLevel: ", fillLevel);
		self.fillLevel = fillLevel;
	end;
	print("<------ self.fillLevel: ", self.fillLevel);
	return self.fillLevel; 	
end;

--for prepending disableSeedingHired to Vehicle:getIsHired()
function calendar:disableSeedingHired(self, superFunc)
  -- credit to HiredConsumesResources mod
  -- Assumption: Looks like only SowingMachine.lua, Sprayer.Lua & Steerable.Lua 
  -- calls this function, to determine if fuel/seeds/fertilizer needs to be decreased or not.
  -- We just "lie", and tell them that it is _not_ controlled by a hired-worker.
	local seedWarn = g_currentMission.environment.calendar.seedWarn;
	if seedWarn == true then
		return false;	
	end;  
end;
--attach to Vehicle.getIsHired -- disable seed usage for hired workers
Vehicle.getIsHired = Utils.prependedFunction(Vehicle.getIsHired, calendar.disableSeedingHired);
--attach to SowingMachine
SowingMachine.load = Utils.appendedFunction(SowingMachine.load, calendar.tempFillLevel);
SowingMachine.update = Utils.appendedFunction(SowingMachine.update, calendar.seedWarning);
SowingMachine.getFillLevel = Utils.overwrittenFunction(SowingMachine.getFillLevel, calendar.disableSeeding);

print("Script Loaded: calendar");
