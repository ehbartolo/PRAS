function initialize_availability!(
    rng::MersenneTwister,
    availability::Vector{Bool}, nexttransition::Vector{Int},
    devices::AbstractAssets, t_last::Int)

    for i in 1:length(devices)

        λ = devices.λ[i, 1]
        μ = devices.μ[i, 1]
        online = rand(rng) < μ / (λ + μ)

        availability[i] = online

        transitionprobs = online ? devices.λ : devices.μ
        nexttransition[i] = randtransitiontime(
            rng, transitionprobs, i, 1, t_last)

    end

    return availability

end

function update_availability!(
    rng::MersenneTwister,
    availability::Vector{Bool}, nexttransition::Vector{Int},
    devices::AbstractAssets, t_now::Int, t_last::Int)

    for i in 1:length(devices)

        if nexttransition[i] == t_now # Unit switches states
            transitionprobs = (availability[i] ⊻= true) ? devices.λ : devices.μ
            nexttransition[i] = randtransitiontime(
                rng, transitionprobs, i, t_now, t_last)
        end

    end

end

function randtransitiontime(
    rng::MersenneTwister, p::Matrix{Float64},
    i::Int, t_now::Int, t_last::Int
)

    cdf = 0
    p_noprevtransition = 1

    x = rand(rng)
    t = t_now + 1

    while t <= t_last
        p_it = p[i,t]
        cdf += p_noprevtransition * p_it
        x < cdf && return t
        p_noprevtransition *= (1 - p_it)
        t += 1
    end

    return t_last + 1

end

function available_capacity(
    availability::Vector{Bool},
    lines::Lines,
    i_bounds::Tuple{Int,Int}, t::Int
)

    avcap_forward = 0
    avcap_backward = 0

    for i in first(i_bounds):last(i_bounds)
        if availability[i]
            avcap_forward += lines.forwardcapacity[i, t]
            avcap_backward += lines.backwardcapacity[i, t]
        end
    end

    return avcap_forward, avcap_backward

end

function available_capacity(
    availability::Vector{Bool},
    assets::AbstractAssets,
    i_bounds::Tuple{Int,Int}, t::Int
)

    avcap = 0

    for i in first(i_bounds):last(i_bounds)
        availability[i] && (avcap += capacity(assets)[i, t])
    end

    return avcap

end

function available_storage_capacity(
    stors_available::Vector{Bool},
    stors_energy::Vector{Int},
    stors::Storages{N,L,T,P,E},
    i_bounds::Tuple{Int,Int}, t::Int
) where {N,L,T,P,E}

    charge_capacity = 0
    discharge_capacity = 0

    for i in first(i_bounds):last(i_bounds)
        if stors_available[i]

            stor_energy = stors_energy[i]
            maxenergy = stors.energycapacity[i, t]

            maxcharge = stors.chargecapacity[i, t]
            chargeefficiency = stors.chargeefficiency[i, t]

            maxdischarge = stors.dischargecapacity[i, t]
            dischargeefficiency = stors.chargeefficiency[i, t]

            charge_capacity +=
                min(maxcharge, round(Int, energytopower(
                    P, (maxenergy - stor_energy) / chargeefficiency, E, L, T)))
            discharge_capacity +=
                min(maxdischarge, round(Int, energytopower(
                    P, stor_energy * dischargeefficiency, E, L, T)))

        end
    end

    return charge_capacity, discharge_capacity

end

function decay_energy!(
    stors_energy::Vector{Int},
    stors::Storages,
    t::Int
)

    for i in 1:length(stors_energy)
        stors_energy[i] *= round(Int, stors.carryoverefficiency[i,t])
    end

end


