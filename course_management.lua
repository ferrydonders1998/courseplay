-- saving // loading coures


-- enables input for course name
function courseplay:showSaveCourseForm(self)
	if table.getn(self.Waypoints) > 0 then
		courseplay.vehicleToSaveCourseIn = self;
		if self.cp.imWriting then
			g_gui:showGui("inputCourseNameDialogue");
			self.cp.imWriting = false
		end
	end;
end;

function courseplay:reload_courses(self, use_real_id)
	for k, v in pairs(self.loaded_courses) do

		courseplay:load_course(self, v, use_real_id)
	end
end

function courseplay:add_course(self, id, use_real_id)
	courseplay:load_course(self, id, use_real_id, true)
end

function courseplay:reinit_courses(self)
	if g_currentMission.courseplay_courses == nil then
		if self.courseplay_courses ~= nil then
			g_currentMission.courseplay_courses = self.courseplay_courses
		else
			courseplay:debug("courseplay_courses is empty", 8)
			if g_server ~= nil then
				courseplay_manager:load_courses();
			end
			return
		end
	end
end

function courseplay:load_course(self, id, use_real_id, add_course_at_end)
	-- global array for courses, no refreshing needed any more
	courseplay:reinit_courses(self);

	if id ~= nil and id ~= "" then
		local searchID = id * 1
		if not use_real_id then
			id = self.selected_course_number + id
		else
			for i = 1, table.getn(g_currentMission.courseplay_courses) do
				if g_currentMission.courseplay_courses[i].id ~= nil then
					if g_currentMission.courseplay_courses[i].id == searchID then
						id = i
						break
					end
				end
			end
		end
		id = id * 1 -- equivalent to tonumber()

		-- negative values mean that add_course_end is true
		if id < 1 then
			id = id * -1
			add_course_at_end = true
		end





		local course = g_currentMission.courseplay_courses[id]
		if course == nil then
			courseplay:debug("no course found", 8)
			return
		end
		if not use_real_id then

			if add_course_at_end == true then
				table.insert(self.loaded_courses, g_currentMission.courseplay_courses[id].id * -1)
			else
				table.insert(self.loaded_courses, g_currentMission.courseplay_courses[id].id)
			end
		end
		--	courseplay:reset_course(self)
		if table.getn(self.Waypoints) == 0 then
			self.numCourses = 1;
			self.Waypoints = course.waypoints
			self.current_course_name = course.name
		else -- Add new course to old course
			if self.current_course_name == nil then --recorded but not saved course
				self.numCourses = 1;
			end;
			courseplay:debug(string.format("course_management 92: %s: self.current_course_name=%s, self.numCourses=%s", nameNum(self), tostring(self.current_course_name), tostring(self.numCourses)), 8);
			
			local course1_waypoints = self.Waypoints
			local course2_waypoints = course.waypoints

			local old_distance = 51
			local lastWP = table.getn(self.Waypoints)
			local wp_found = false
			local new_wp = 1
			-- go through all waypoints and try to find a waypoint of the next course near a crossing

			if add_course_at_end ~= true then
				for number, course1_wp in pairs(course1_waypoints) do
					--courseplay:debug(number, 3)
					if course1_wp.crossing == true and course1_wp.merged == nil and wp_found == false and number > self.startlastload then
						-- go through the second course from behind!!
						for number_2 = 1, table.getn(course2_waypoints) do
							local course2_wp = course2_waypoints[number_2]
							if course2_wp.crossing == true and course2_wp.merged == nil and wp_found == false then
								local distance_between_waypoints = courseplay:distance(course1_wp.cx, course1_wp.cz, course2_wp.cx, course2_wp.cz)
								if distance_between_waypoints < 50 and distance_between_waypoints ~= 0 then
									if distance_between_waypoints < old_distance then
										old_distance = distance_between_waypoints
										lastWP = number
										course1_waypoints[lastWP].merged = true
										new_wp = number_2
										wp_found = true
									end
								end
							end
						end
					end
				end
			end

			if wp_found == false then
				courseplay:debug(nameNum(self) .. ": no waypoint found", 8)
			end

			self.Waypoints = {}

			for i = 1, lastWP do
				table.insert(self.Waypoints, course1_waypoints[i])
			end
			self.startlastload = lastWP

			local lastNewWP = table.getn(course.waypoints)
			for i = new_wp, lastNewWP do
				table.insert(self.Waypoints, course.waypoints[i])
			end
			self.Waypoints[lastWP + 1].merged = true
			self.numCourses = self.numCourses + 1;
			self.current_course_name = string.format("%d %s", self.numCourses, courseplay.locales.CPCourseAdded)
		end
		if table.getn(self.Waypoints) == 4 then
			self.createCourse = true
		else
			self.play = true
		end
		
		self.recordnumber = 1
		courseplay:RefreshSigns(self) -- this adds the signs to the course

		self.cp.hasGeneratedCourse = false;
		courseplay:validateCourseGenerationData(self);
		
		courseplay:validateCanSwitchMode(self);
	end
end

function courseplay:reset_merged(self)
	for i = 1, table.getn(g_currentMission.courseplay_courses) do
		for num, wp in pairs(g_currentMission.courseplay_courses[i].waypoints) do
			wp.merged = nil
		end
	end
end

function courseplay:clear_course(self, id)
	if id ~= nil then
		id = self.selected_course_number + id
		local course = g_currentMission.courseplay_courses[id]
		if course == nil then
			return
		end
		table.remove(g_currentMission.courseplay_courses, id)
		courseplay:save_courses(self)
		courseplay:RefreshGlobalSigns(self)
	end
end

-- saves coures to xml-file
function courseplay:save_courses(self)
	if g_server ~= nil then
		local savegame = g_careerScreen.savegames[g_careerScreen.selectedIndex];
		if savegame ~= nil and g_currentMission.courseplay_courses ~= nil and table.getn(g_currentMission.courseplay_courses) > 0 then
			local file = io.open(savegame.savegameDirectory .. "/courseplay.xml", "w");
			if file ~= nil then
				file:write('<?xml version="1.0" encoding="utf-8" standalone="no" ?>\n<XML>\n\t<courseplayHud posX="' .. courseplay.hud.infoBasePosX .. '" posY="' .. courseplay.hud.infoBasePosY .. '" />\n\t<courses>\n');

				for i,course in ipairs(g_currentMission.courseplay_courses) do
					file:write('\t\t<course name="' .. course.name .. '" id="' .. course.id .. '" numWaypoints="' .. table.getn(course.waypoints) .. '">\n');
					for wpNum,wp in ipairs(course.waypoints) do
						local wpContent = '\t\t\t<waypoint' .. wpNum .. ' ';
						wpContent = wpContent .. 'pos="' .. tostring(Utils.getNoNil(courseplay:round(wp.cx, 4), 0)) .. ' ' .. tostring(Utils.getNoNil(courseplay:round(wp.cz, 4), 0)) .. '" ';
						wpContent = wpContent .. 'angle="' .. tostring(Utils.getNoNil(wp.angle, 0)) .. '" ';
						wpContent = wpContent .. 'wait="' .. tostring(Utils.getNoNil(courseplay:boolToInt(wp.wait), 0)) .. '" ';
						wpContent = wpContent .. 'crossing="' .. tostring(Utils.getNoNil(courseplay:boolToInt(wp.crossing), 0)) .. '" ';
						wpContent = wpContent .. 'rev="' .. tostring(Utils.getNoNil(courseplay:boolToInt(wp.rev), 0)) .. '" ';
						wpContent = wpContent .. 'speed="' .. tostring(courseplay:round(Utils.getNoNil(wp.speed, 0), 5)) .. '" ';
						wpContent = wpContent .. 'turn="' .. tostring(Utils.getNoNil(wp.turn, false)) .. '" ';
						wpContent = wpContent .. 'turnstart="' .. tostring(Utils.getNoNil(courseplay:boolToInt(wp.turnStart), 0)) .. '" ';
						wpContent = wpContent .. 'turnend="' .. tostring(Utils.getNoNil(courseplay:boolToInt(wp.turnEnd), 0)) .. '" ';
						wpContent = wpContent .. 'ridgemarker="' .. tostring(Utils.getNoNil(wp.ridgeMarker, 0)) .. '" ';
						wpContent = wpContent .. 'generated="' .. tostring(Utils.getNoNil(wp.generated, false)) .. '" ';
						wpContent = wpContent .. '/>\n';

						file:write(wpContent);
					end;
					file:write('\t\t</course>\n');
				end;
				file:write('\t</courses>\n</XML>');
				file:close();
			else
				print("Error: Courseplay courses could not be saved to " .. tostring(savegame.savegameDirectory) .. "/courseplay.xml"); 
			end;
		end;
	end;
end;


--Update all vehicles' course list arrow displays
function courseplay:validateCourseListArrows(numCourses)
	for _,vehicle in pairs(g_currentMission.steerables) do
		if vehicle.cp ~= nil and vehicle.cp.courseListPrev ~= nil and vehicle.cp.courseListNext ~= nil and vehicle.selected_course_number ~= nil then
			vehicle.cp.courseListPrev = vehicle.selected_course_number > 0;
			vehicle.cp.courseListNext = vehicle.selected_course_number < (numCourses - courseplay.hud.numLines);
		end;
	end;
end;