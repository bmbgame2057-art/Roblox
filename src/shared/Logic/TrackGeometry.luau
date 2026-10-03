--!strict
-- Converts a track piece's Path description into sampled geometry in piece-local space.
--
-- Steering: standard pieces may be generated with +-GameConfig.Track.SteerYawDeg of extra yaw.
-- This is stored per piece and lets the generator keep ramps centred in their lane.
--
-- Socket standard (shared by every piece):
--   * Entry socket = local origin, level, facing -Z (the ride direction), up = +Y
--   * Exit socket  = Samples[#Samples], level (no pitch, no roll), facing the exit heading
-- Because both sockets are always level, any piece can follow any other piece.
--
-- Samples are spaced at most ~GameConfig.Track.MaxSampleSpacing studs of arc apart; they are
-- used for placement validation, the ride path, and building the visual model.

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local TrackDefinitions = require(Shared.Definitions.TrackDefinitions)

type TrackDefinition = TrackDefinitions.TrackDefinition
type PathDefinition = TrackDefinitions.PathDefinition

export type Geometry = {
	Key: string,
	Kind: string,
	Samples: { CFrame },
	Dist: { number }, -- cumulative arc length at each sample
	Length: number, -- total arc length
	Exit: CFrame, -- exit socket (equals the last sample)
	Gaps: { { number } }, -- arc-length ranges with no deck (jumps)
	TopIndex: number, -- index of the highest sample (used for loop frames)
	Center: Vector3, -- average sample position (spiral columns)
}

local TRACK = GameConfig.Track
local LANES = GameConfig.Lanes
local SPACING = TRACK.MaxSampleSpacing

local TrackGeometry = {}

local cache: { [string]: Geometry } = {}

local function smoothstep(u: number): number
	return u * u * (3 - 2 * u)
end

local function smoothstepDerivative(u: number): number
	return 6 * u * (1 - u)
end

local function levelFrame(position: Vector3, heading: number): CFrame
	local look = Vector3.new(-math.sin(heading), 0, -math.cos(heading))
	return CFrame.lookAt(position, position + look, Vector3.yAxis)
end

local function finalize(key: string, kind: string, samples: { CFrame }, gapsU: { { number } }?): Geometry
	local dist = table.create(#samples)
	dist[1] = 0
	local center = samples[1].Position
	local topIndex = 1
	for i = 2, #samples do
		dist[i] = dist[i - 1] + (samples[i].Position - samples[i - 1].Position).Magnitude
		center += samples[i].Position
		if samples[i].Position.Y > samples[topIndex].Position.Y then
			topIndex = i
		end
	end
	local gaps = {}
	if gapsU then
		-- Standard paths sample uniformly in u, so u maps to a sample index linearly.
		local steps = #samples - 1
		for _, range in gapsU do
			local function distAt(u: number): number
				local f = u * steps
				local i = math.clamp(math.floor(f), 0, steps - 1)
				local alpha = f - i
				return dist[i + 1] + (dist[i + 2] - dist[i + 1]) * alpha
			end
			table.insert(gaps, { distAt(range[1]), distAt(range[2]) })
		end
	end
	return {
		Key = key,
		Kind = kind,
		Samples = samples,
		Dist = dist,
		Length = dist[#dist],
		Exit = samples[#samples],
		Gaps = gaps,
		TopIndex = topIndex,
		Center = center / #samples,
	}
end

local function buildStandard(path: PathDefinition, mirror: boolean, steer: number, steps: number?): { CFrame }
	local sign = if mirror then -1 else 1
	local length = path.Length or 16
	local height = path.Height or 0
	local yaw = math.rad(path.Yaw or 0) * sign + math.rad(TRACK.SteerYawDeg) * steer
	local bump = path.Bump or 0
	local bank = math.rad(path.Bank or 0) * sign

	local n = steps
	if not n then
		local estimatedArc = math.sqrt(length * length + height * height + (2 * bump) ^ 2)
		local count = math.ceil(estimatedArc / SPACING)
		count = math.max(count, math.ceil(math.abs(yaw) / math.rad(7.5)))
		if height ~= 0 or bump ~= 0 then
			count = math.max(count, 8)
		end
		n = math.max(count, 2)
	end
	local stepCount: number = n :: number

	local ds = length / stepCount
	local samples = table.create(stepCount + 1)
	local x, z = 0, 0
	for k = 0, stepCount do
		local u = k / stepCount
		if k > 0 then
			-- Midpoint integration of the heading gives a near-exact circular arc for curves.
			local headingMid = yaw * ((k - 0.5) / stepCount)
			x -= math.sin(headingMid) * ds
			z -= math.cos(headingMid) * ds
		end
		local heading = yaw * u
		local y = height * smoothstep(u) + bump * math.sin(math.pi * u) ^ 2
		local position = Vector3.new(x, y, z)
		if k == stepCount then
			samples[k + 1] = levelFrame(position, yaw)
		elseif k == 0 then
			samples[k + 1] = CFrame.new()
		else
			local dy = height * smoothstepDerivative(u) + bump * math.pi * math.sin(2 * math.pi * u)
			local tangent = Vector3.new(-math.sin(heading) * length, dy, -math.cos(heading) * length).Unit
			local roll = bank * math.sin(math.pi * u)
			samples[k + 1] = CFrame.lookAt(position, position + tangent, Vector3.yAxis) * CFrame.Angles(0, 0, roll)
		end
	end
	return samples
end

local function buildLoop(path: PathDefinition, mirror: boolean): { CFrame }
	local sign = if mirror then -1 else 1
	local radius = path.Radius or 12
	local shift = (path.Shift or 14) * sign
	local leadIn = path.LeadIn or (radius + 3)
	local leadOut = path.LeadOut or (radius + 3)

	local positions: { Vector3 } = {}
	local tangents: { Vector3 } = {}
	local ups: { Vector3 } = {}
	local function add(position: Vector3, tangent: Vector3, up: Vector3)
		table.insert(positions, position)
		table.insert(tangents, tangent.Unit)
		table.insert(ups, up.Unit)
	end

	local inSteps = math.max(2, math.ceil(leadIn / SPACING))
	for k = 0, inSteps - 1 do
		add(Vector3.new(0, 0, -leadIn * (k / inSteps)), Vector3.new(0, 0, -1), Vector3.yAxis)
	end

	local loopSteps = math.max(24, math.ceil(2 * math.pi * radius / (SPACING * 0.6)))
	for k = 0, loopSteps do
		local u = k / loopSteps
		local theta = 2 * math.pi * u
		add(
			Vector3.new(shift * smoothstep(u), radius * (1 - math.cos(theta)), -(leadIn + radius * math.sin(theta))),
			Vector3.new(
				shift * smoothstepDerivative(u) / (2 * math.pi),
				radius * math.sin(theta),
				-radius * math.cos(theta)
			),
			Vector3.new(0, math.cos(theta), math.sin(theta))
		)
	end

	local outSteps = math.max(2, math.ceil(leadOut / SPACING))
	for k = 1, outSteps do
		add(Vector3.new(shift, 0, -leadIn - leadOut * (k / outSteps)), Vector3.new(0, 0, -1), Vector3.yAxis)
	end

	-- The deck's up vector points at the loop centre. (cos t, sin t) in the YZ plane is exactly
	-- perpendicular to the tangent even with the sideways shift, so frames never twist.
	local samples = table.create(#positions)
	for i, position in positions do
		local tangent = tangents[i]
		local up = ups[i]
		samples[i] = CFrame.fromMatrix(position, tangent:Cross(up), up)
	end
	samples[1] = CFrame.new()
	samples[#samples] = levelFrame(positions[#positions], 0)
	return samples
end

local function maxSpacing(samples: { CFrame }): number
	local worst = 0
	for i = 2, #samples do
		worst = math.max(worst, (samples[i].Position - samples[i - 1].Position).Magnitude)
	end
	return worst
end

-- Whether a piece supports steering variants (small extra yaw used to keep ramps centred).
function TrackGeometry.CanSteer(def: TrackDefinition): boolean
	return def.Path.Kind ~= "Loop"
end

local function normalizeSteer(def: TrackDefinition, steer: number?): number
	if not steer or not TrackGeometry.CanSteer(def) then
		return 0
	end
	return math.clamp(math.round(steer), -TRACK.SteerLevels, TRACK.SteerLevels)
end

function TrackGeometry.Build(def: TrackDefinition, mirror: boolean, steer: number?): Geometry
	local steerSign = normalizeSteer(def, steer)
	local key = def.Id .. (if mirror then "|M" else "") .. (if steerSign ~= 0 then "|S" .. steerSign else "")
	local path = def.Path
	if path.Kind == "Loop" then
		return finalize(key, "Loop", buildLoop(path, mirror))
	end
	local samples = buildStandard(path, mirror, steerSign)
	local worst = maxSpacing(samples)
	if worst > SPACING * 1.15 then
		-- Steep or bumpy paths stretch some intervals; resample with proportionally more steps.
		local steps = math.ceil((#samples - 1) * worst / SPACING)
		samples = buildStandard(path, mirror, steerSign, steps)
	end
	local kind = if TrackDefinitions.HasTag(def, "Spiral") then "Spiral" else "Standard"
	return finalize(key, kind, samples, if path.Gap then { path.Gap } else nil)
end

function TrackGeometry.Get(def: TrackDefinition, mirror: boolean?, steer: number?): Geometry
	local isMirrored = mirror == true and def.Mirror
	local steerSign = normalizeSteer(def, steer)
	local key = def.Id .. (if isMirrored then "|M" else "") .. (if steerSign ~= 0 then "|S" .. steerSign else "")
	local geometry = cache[key]
	if not geometry then
		geometry = TrackGeometry.Build(def, isMirrored, steerSign)
		cache[key] = geometry
	end
	return geometry
end

function TrackGeometry.GetById(id: string, mirror: boolean?, steer: number?): Geometry?
	local def = TrackDefinitions.ById[id]
	if not def then
		return nil
	end
	return TrackGeometry.Get(def, mirror, steer)
end

-- The launch kicker at the end of every lane. Unlike pieces, its exit is pitched upward.
function TrackGeometry.GetLip(): Geometry
	local cached = cache["__Lip"]
	if cached then
		return cached
	end
	local length = LANES.LipLength
	local rise = LANES.LipRise
	local steps = 10
	local samples = table.create(steps + 1)
	for k = 0, steps do
		local u = k / steps
		local position = Vector3.new(0, rise * u * u, -length * u)
		local tangent = Vector3.new(0, 2 * rise * u, -length).Unit
		samples[k + 1] = CFrame.lookAt(position, position + tangent, Vector3.yAxis)
	end
	local geometry = finalize("__Lip", "Lip", samples)
	cache["__Lip"] = geometry
	return geometry
end

-- Interpolated frame at an arc-length distance along the geometry.
function TrackGeometry.SampleAt(geometry: Geometry, distance: number): CFrame
	local dist = geometry.Dist
	local samples = geometry.Samples
	if distance <= 0 then
		return samples[1]
	end
	if distance >= geometry.Length then
		return samples[#samples]
	end
	local low, high = 1, #dist
	while high - low > 1 do
		local mid = (low + high) // 2
		if dist[mid] <= distance then
			low = mid
		else
			high = mid
		end
	end
	local span = dist[high] - dist[low]
	local alpha = if span > 0 then (distance - dist[low]) / span else 0
	return samples[low]:Lerp(samples[high], alpha)
end

function TrackGeometry.IsInGap(geometry: Geometry, distance: number): boolean
	for _, range in geometry.Gaps do
		if distance > range[1] and distance < range[2] then
			return true
		end
	end
	return false
end

return TrackGeometry
