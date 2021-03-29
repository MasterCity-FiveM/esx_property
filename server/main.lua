ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

function GetProperty(name)
	for i=1, #Config.Properties, 1 do
		if Config.Properties[i].name == name then
			return Config.Properties[i]
		end
	end
end

function SetPropertyOwned(name, price, rented, owner)
	MySQL.Async.execute('INSERT INTO owned_properties (name, price, rented, owner) VALUES (@name, @price, @rented, @owner)', {
		['@name']   = name,
		['@price']  = price,
		['@rented'] = (rented and 1 or 0),
		['@owner']  = owner
	}, function(rowsChanged)
		local xPlayer = ESX.GetPlayerFromIdentifier(owner)

		if xPlayer then
			TriggerClientEvent('esx_property:setPropertyOwned', xPlayer.source, name, true, rented)

			if rented then
				TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text = _U('rent_for', ESX.Math.GroupDigits(price)), type = "info", timeout = 5000, layout = "bottomCenter"})
			else
				TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text = _U('buy_for', ESX.Math.GroupDigits(price)), type = "info", timeout = 5000, layout = "bottomCenter"})
			end
		end
	end)
end

function RemoveOwnedProperty(name, owner, noPay)
	MySQL.Async.fetchAll('SELECT id, rented, price FROM owned_properties WHERE name = @name AND owner = @owner', {
		['@name']  = name,
		['@owner'] = owner
	}, function(result)
		if result[1] then
			MySQL.Async.execute('DELETE FROM owned_properties WHERE id = @id', {
				['@id'] = result[1].id
			}, function(rowsChanged)
				local xPlayer = ESX.GetPlayerFromIdentifier(owner)

				if xPlayer then
					xPlayer.triggerEvent('esx_property:setPropertyOwned', name, false)

					if not noPay then
						if result[1].rented == 1 then
							TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text = _U('moved_out'), type = "error", timeout = 5000, layout = "bottomCenter"})
						else
							local sellPrice = ESX.Math.Round(result[1].price / Config.SellModifier)

							TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text = _U('moved_out_sold', ESX.Math.GroupDigits(sellPrice)), type = "info", timeout = 5000, layout = "bottomCenter"})
							xPlayer.addAccountMoney('bank', sellPrice)
						end
					end
				end
			end)
		end
	end)
end

MySQL.ready(function()
	Citizen.Wait(1500)

	MySQL.Async.fetchAll('SELECT * FROM `properties`', {}, function(properties)

		for i=1, #properties, 1 do
			local entering  = nil
			local exit      = nil
			local inside    = nil
			local outside   = nil
			local isSingle  = nil
			local isRoom    = nil
			local isGateway = nil
			local roomMenu  = nil

			if properties[i].entering then
				entering = json.decode(properties[i].entering)
			end

			if properties[i].exit then
				exit = json.decode(properties[i].exit)
			end

			if properties[i].inside then
				inside = json.decode(properties[i].inside)
			end

			if properties[i].outside then
				outside = json.decode(properties[i].outside)
			end

			if properties[i].is_single == 0 then
				isSingle = false
			else
				isSingle = true
			end

			if properties[i].is_room == 0 then
				isRoom = false
			else
				isRoom = true
			end

			if properties[i].is_gateway == 0 then
				isGateway = false
			else
				isGateway = true
			end

			if properties[i].room_menu then
				roomMenu = json.decode(properties[i].room_menu)
			end

			table.insert(Config.Properties, {
				name      = properties[i].name,
				label     = properties[i].label,
				entering  = entering,
				exit      = exit,
				inside    = inside,
				outside   = outside,
				ipls      = json.decode(properties[i].ipls),
				gateway   = properties[i].gateway,
				isSingle  = isSingle,
				isRoom    = isRoom,
				isGateway = isGateway,
				roomMenu  = roomMenu,
				price     = properties[i].price
			})
		end

		TriggerClientEvent('esx_property:sendProperties', -1, Config.Properties)
	end)
end)

ESX.RegisterServerCallback('esx_property:getProperties', function(source, cb)
	ESX.RunCustomFunction("anti_ddos", source, 'esx_property:getProperties', {})
	cb(Config.Properties)
end)

AddEventHandler('esx_ownedproperty:getOwnedProperties', function(cb)
	MySQL.Async.fetchAll('SELECT * FROM owned_properties', {}, function(result)
		local properties = {}

		for i=1, #result, 1 do
			table.insert(properties, {
				id     = result[i].id,
				name   = result[i].name,
				label  = GetProperty(result[i].name).label,
				price  = result[i].price,
				rented = (result[i].rented == 1 and true or false),
				owner  = result[i].owner
			})
		end

		cb(properties)
	end)
end)

AddEventHandler('esx_property:setPropertyOwned', function(name, price, rented, owner)
	SetPropertyOwned(name, price, rented, owner)
end)

AddEventHandler('esx_property:removeOwnedProperty', function(name, owner)
	RemoveOwnedProperty(name, owner)
end)

RegisterNetEvent('esx_property:rentProperty')
AddEventHandler('esx_property:rentProperty', function(propertyName)
	ESX.RunCustomFunction("anti_ddos", source, 'esx_property:rentProperty', {propertyName = propertyName})
	local xPlayer  = ESX.GetPlayerFromId(source)
	local property = GetProperty(propertyName)
	local rent     = ESX.Math.Round(property.price / Config.RentModifier)

	SetPropertyOwned(propertyName, rent, true, xPlayer.identifier)
end)

RegisterNetEvent('esx_property:buyProperty')
AddEventHandler('esx_property:buyProperty', function(propertyName)
	ESX.RunCustomFunction("anti_ddos", source, 'esx_property:buyProperty', {propertyName = propertyName})
	local xPlayer  = ESX.GetPlayerFromId(source)
	local property = GetProperty(propertyName)

	if property.price <= xPlayer.getMoney() then
		xPlayer.removeMoney(property.price)
		SetPropertyOwned(propertyName, property.price, false, xPlayer.identifier)
	else
		TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text = _U('not_enough'), type = "error", timeout = 5000, layout = "bottomCenter"})
	end
end)

RegisterNetEvent('esx_property:removeOwnedProperty')
AddEventHandler('esx_property:removeOwnedProperty', function(propertyName)
	ESX.RunCustomFunction("anti_ddos", source, 'esx_property:removeOwnedProperty', {propertyName = propertyName})
	local xPlayer = ESX.GetPlayerFromId(source)
	RemoveOwnedProperty(propertyName, xPlayer.identifier)
end)

AddEventHandler('esx_property:removeOwnedPropertyIdentifier', function(propertyName, identifier)
	ESX.RunCustomFunction("anti_ddos", source, 'esx_property:removeOwnedPropertyIdentifier', {propertyName = propertyName, identifier = identifier})
	RemoveOwnedProperty(propertyName, identifier)
end)

RegisterNetEvent('esx_property:saveLastProperty')
AddEventHandler('esx_property:saveLastProperty', function(property)
	ESX.RunCustomFunction("anti_ddos", source, 'esx_property:saveLastProperty', {property = property})
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.Async.execute('UPDATE users SET last_property = @last_property WHERE identifier = @identifier', {
		['@last_property'] = property,
		['@identifier']    = xPlayer.identifier
	})
end)

RegisterNetEvent('esx_property:deleteLastProperty')
AddEventHandler('esx_property:deleteLastProperty', function()
	ESX.RunCustomFunction("anti_ddos", source, 'esx_property:deleteLastProperty', {})
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.Async.execute('UPDATE users SET last_property = NULL WHERE identifier = @identifier', {
		['@identifier'] = xPlayer.identifier
	})
end)

RegisterNetEvent('esx_property:getItem')
AddEventHandler('esx_property:getItem', function(owner, type, item, count)
	ESX.RunCustomFunction("anti_ddos", source, 'esx_property:getItem', {owner = owner, type = type, item = item, count = count})
	local xPlayer = ESX.GetPlayerFromId(source)
	local xPlayerOwner = ESX.GetPlayerFromIdentifier(owner)

	if type == 'item_standard' then
		TriggerEvent('esx_addoninventory:getInventory', 'property', xPlayerOwner.identifier, function(inventory)
			local inventoryItem = inventory.getItem(item)

			-- is there enough in the property?
			if count > 0 and inventoryItem.count >= count then
				-- can the player carry the said amount of x item?
				if xPlayer.canCarryItem(item, count) then
					inventory.removeItem(item, count)
					xPlayer.addInventoryItem(item, count)
					TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text =_U('have_withdrawn', count, inventoryItem.label), type = "info", timeout = 5000, layout = "bottomCenter"})
				else
					TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text =_U('player_cannot_hold'), type = "error", timeout = 5000, layout = "bottomCenter"})
				end
			else
				TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text =_U('not_enough_in_property'), type = "error", timeout = 5000, layout = "bottomCenter"})
			end
		end)
	elseif type == 'item_account' then
		TriggerEvent('esx_addonaccount:getAccount', 'property_' .. item, xPlayerOwner.identifier, function(account)
			if account.money >= count then
				account.removeMoney(count)
				xPlayer.addAccountMoney(item, count)
			else
				TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text = _U('amount_invalid'), type = "error", timeout = 5000, layout = "bottomCenter"})
			end
		end)
	elseif type == 'item_weapon' then
		TriggerEvent('esx_datastore:getDataStore', 'property', xPlayerOwner.identifier, function(store)
			local storeWeapons = store.get('weapons') or {}
			local weaponName   = nil
			local ammo         = nil

			for i=1, #storeWeapons, 1 do
				if storeWeapons[i].name == item then
					weaponName = storeWeapons[i].name
					ammo       = storeWeapons[i].ammo

					table.remove(storeWeapons, i)
					break
				end
			end

			store.set('weapons', storeWeapons)
			xPlayer.addWeapon(weaponName, ammo)
		end)
	end
end)

RegisterNetEvent('esx_property:putItem')
AddEventHandler('esx_property:putItem', function(owner, type, item, count)
	ESX.RunCustomFunction("anti_ddos", source, 'esx_property:putItem', {owner = owner, type = type, item = item, count = count})
	local xPlayer = ESX.GetPlayerFromId(source)
	local xPlayerOwner = ESX.GetPlayerFromIdentifier(owner)

	if type == 'item_standard' then
		local playerItemCount = xPlayer.getInventoryItem(item).count

		if playerItemCount >= count and count > 0 then
			TriggerEvent('esx_addoninventory:getInventory', 'property', xPlayerOwner.identifier, function(inventory)
				xPlayer.removeInventoryItem(item, count)
				inventory.addItem(item, count)
				TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text = _U('have_deposited', count, inventory.getItem(item).label), type = "info", timeout = 5000, layout = "bottomCenter"})
			end)
		else
			TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text = _U('invalid_quantity'), type = "error", timeout = 5000, layout = "bottomCenter"})
		end
	elseif type == 'item_account' then
		if xPlayer.getAccount(item).money >= count and count > 0 then
			xPlayer.removeAccountMoney(item, count)

			TriggerEvent('esx_addonaccount:getAccount', 'property_' .. item, xPlayerOwner.identifier, function(account)
				account.addMoney(count)
			end)
		else
			TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text = _U('invalid_quantity'), type = "error", timeout = 5000, layout = "bottomCenter"})
		end
	elseif type == 'item_weapon' then
		if xPlayer.hasWeapon(item) then
			xPlayer.removeWeapon(item)

			TriggerEvent('esx_datastore:getDataStore', 'property', xPlayerOwner.identifier, function(store)
				local storeWeapons = store.get('weapons') or {}

				table.insert(storeWeapons, {
					name = item,
					ammo = count
				})

				store.set('weapons', storeWeapons)
			end)
		end
	end
end)

ESX.RegisterServerCallback('esx_property:getOwnedProperties', function(source, cb)
	ESX.RunCustomFunction("anti_ddos", source, 'esx_property:getOwnedProperties', {})
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.Async.fetchAll('SELECT name, rented FROM owned_properties WHERE owner = @owner', {
		['@owner'] = xPlayer.identifier
	}, function(result)
		cb(result)
	end)
end)

ESX.RegisterServerCallback('esx_property:getLastProperty', function(source, cb)
	ESX.RunCustomFunction("anti_ddos", source, 'esx_property:getLastProperty', {})
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.Async.fetchAll('SELECT last_property FROM users WHERE identifier = @identifier', {
		['@identifier'] = xPlayer.identifier
	}, function(users)
		cb(users[1].last_property)
	end)
end)

ESX.RegisterServerCallback('esx_property:getPropertyInventory', function(source, cb, owner)
	ESX.RunCustomFunction("anti_ddos", source, 'esx_property:getPropertyInventory', {owner = owner})
	local xPlayer    = ESX.GetPlayerFromIdentifier(owner)
	local blackMoney = 0
	local items      = {}
	local weapons    = {}

	TriggerEvent('esx_addonaccount:getAccount', 'property_black_money', xPlayer.identifier, function(account)
		blackMoney = account.money
	end)

	TriggerEvent('esx_addoninventory:getInventory', 'property', xPlayer.identifier, function(inventory)
		items = inventory.items
	end)

	TriggerEvent('esx_datastore:getDataStore', 'property', xPlayer.identifier, function(store)
		weapons = store.get('weapons') or {}
	end)

	cb({
		blackMoney = blackMoney,
		items      = items,
		weapons    = weapons
	})
end)

ESX.RegisterServerCallback('esx_property:getPlayerInventory', function(source, cb)
	ESX.RunCustomFunction("anti_ddos", source, 'esx_property:getPlayerInventory', {})
	local xPlayer    = ESX.GetPlayerFromId(source)
	local blackMoney = xPlayer.getAccount('black_money').money
	local items      = xPlayer.inventory

	cb({
		blackMoney = blackMoney,
		items      = items,
		weapons    = xPlayer.getLoadout()
	})
end)

ESX.RegisterServerCallback('esx_property:getPlayerDressing', function(source, cb)
	ESX.RunCustomFunction("anti_ddos", source, 'esx_property:getPlayerDressing', {})
	local xPlayer  = ESX.GetPlayerFromId(source)

	TriggerEvent('esx_datastore:getDataStore', 'property', xPlayer.identifier, function(store)
		local count  = store.count('dressing')
		local labels = {}

		for i=1, count, 1 do
			local entry = store.get('dressing', i)
			table.insert(labels, entry.label)
		end

		cb(labels)
	end)
end)

ESX.RegisterServerCallback('esx_property:getPlayerOutfit', function(source, cb, num)
	ESX.RunCustomFunction("anti_ddos", source, 'esx_property:getPlayerOutfit', {num = num})
	local xPlayer  = ESX.GetPlayerFromId(source)

	TriggerEvent('esx_datastore:getDataStore', 'property', xPlayer.identifier, function(store)
		local outfit = store.get('dressing', num)
		cb(outfit.skin)
	end)
end)

RegisterNetEvent('esx_property:removeOutfit')
AddEventHandler('esx_property:removeOutfit', function(label)
	ESX.RunCustomFunction("anti_ddos", source, 'esx_property:removeOutfit', {label = label})
	local xPlayer = ESX.GetPlayerFromId(source)

	TriggerEvent('esx_datastore:getDataStore', 'property', xPlayer.identifier, function(store)
		local dressing = store.get('dressing') or {}

		table.remove(dressing, label)
		store.set('dressing', dressing)
	end)
end)

function payRent(d, h, m)
	local tasks, timeStart = {}, os.clock()
	print('[esx_property] [^2INFO^7] Paying rent cron job started')

	MySQL.Async.fetchAll('SELECT * FROM owned_properties WHERE rented = 1', {}, function(result)
		for k,v in ipairs(result) do
			table.insert(tasks, function(cb)
				local xPlayer = ESX.GetPlayerFromIdentifier(v.owner)

				if xPlayer then
					if xPlayer.getAccount('bank').money >= v.price then
						xPlayer.removeAccountMoney('bank', v.price)
						TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text = _U('paid_rent', ESX.Math.GroupDigits(v.price), GetProperty(v.name).label), type = "info", timeout = 5000, layout = "bottomCenter"})
					else
						TriggerClientEvent("pNotify:SendNotification", xPlayer.source, { text = _U('paid_rent_evicted', GetProperty(v.name).label, ESX.Math.GroupDigits(v.price)), type = "info", timeout = 5000, layout = "bottomCenter"})
						RemoveOwnedProperty(v.name, v.owner, true)
					end
				else
					MySQL.Async.fetchScalar('SELECT accounts FROM users WHERE identifier = @identifier', {
						['@identifier'] = v.owner
					}, function(accounts)
						if accounts then
							local playerAccounts = json.decode(accounts)

							if playerAccounts and playerAccounts.bank then
								if playerAccounts.bank >= v.price then
									playerAccounts.bank = playerAccounts.bank - v.price

									MySQL.Async.execute('UPDATE users SET accounts = @accounts WHERE identifier = @identifier', {
										['@identifier'] = v.owner,
										['@accounts'] = json.encode(playerAccounts)
									})
								else
									RemoveOwnedProperty(v.name, v.owner, true)
								end
							end
						end
					end)
				end

				TriggerEvent('esx_addonaccount:getSharedAccount', 'society_realestateagent', function(account)
					if account ~= nil then
						account.addMoney(v.price)
					end
				end)

				cb()
			end)
		end

		Async.parallelLimit(tasks, 5, function(results) end)

		local elapsedTime = os.clock() - timeStart
		print(('[esx_property] [^2INFO^7] Paying rent cron job took %s seconds'):format(elapsedTime))
	end)
end

TriggerEvent('cron:runAt', 22, 0, payRent)
