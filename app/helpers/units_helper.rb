module UnitsHelper

  def supportedUnits
    # Units we can convert
    ["cm3(STP)/g", "cm3(STP)/cm3", "g/l", "mg/g", "mmol/g", "mol/kg", "cm3/cm3"]
  end

  def frontEndUnits
    # Units we list on the frontend as conversion options
    ["cm3(STP)/g", "cm3(STP)/cm3", "g/l", "mg/g", "mmol/g", "mol/kg"]
  end

  class UnsupportedGasUnit < StandardError
    def initialize(msg = nil)
      super
    end
  end

  class UnsupportedPressureUnit < StandardError
    def initialize(msg = nil)
      super
    end
  end

  def parseUnits(from, to)
    def parseUnit(unit)
      split = unit.split("/")
      return split[0], split[1]
    end

    gasFrom, mofFrom = parseUnit(from)
    gasTo, mofTo = parseUnit(to)
    return gasFrom, gasTo, mofFrom, mofTo
  end


  def get_pressure_in_bar(isodata)
    pressure_units = Classification.find(isodata.isotherm.pressure_units_id)
    if pressure_units.data != 0 and !pressure_units.data.nil?
      return isodata.pressure * pressure_units.data
    else
      raise UnsupportedPressureUnit.new("#{pressure_units.name} is not a supported pressure unit")
    end
  end

  def convert_adsorption_units_wrapped(from, to, value, gas, mof, temp, pressureBar)
    gasFrom, gasTo, mofFrom, mofTo = parseUnits(from, to)
    pressureAtm = pressureBar / 1.01325
    numerator = convert_gas_unit(gasFrom, gasTo, value, gas.molarMass, temp, pressureAtm)
    denominator = convert_mof_unit(mofFrom, mofTo, 1, mof.volumeA3, mof.atomicMass)
    return numerator / denominator

  end
  def convert_adsorption_units(from, to, isodata)
    raise UnsupportedGasUnit.new("#{from} is not a supported adsorption unit") unless supportedUnits.include?(from)
    raise UnsupportedGasUnit.new("#{to} is not a supported adsorption unit") unless supportedUnits.include?(to)

    gas = isodata.gas
    mof = isodata.isotherm.mof
    value = isodata.loading
    tempK = isodata.isotherm.temp
    pressureBar = get_pressure_in_bar(isodata)
    return convert_adsorption_units_wrapped(from, to, value, gas, mof, tempK, pressureBar)
  end

  def convert_mof_unit(from, to, value, volumeA3, unitCellMass)
    supported = ["cm3", "g", "l", "kg", "mg"]
    raise UnsupportedGasUnit("#{from} is not a supported MOF unit") if supported.index(from).nil?
    raise UnsupportedGasUnit("#{to} is not a supported MOF unit") if supported.index(to).nil?

    avogadro = 6.0221409e+23
    molesOfUnitCells = nil

    # volume of a mol of unit cells
    volumeMolCm3 = (volumeA3 * avogadro) / 1e+24 #  [cm3/mol]

    # molar mass of mof
    molarMass = unitCellMass # [g/mol]

    if from == "cm3"
      molesOfUnitCells = value / volumeMolCm3
    elsif from == "g"
      molesOfUnitCells = value / molarMass
    elsif from == "l"
      m3 = value / 1000.0
      cm3 = m3 * 100.0 * 100.0 * 100.0
      molesOfUnitCells = cm3 / volumeMolCm3
    elsif from == "kg"
      grams = value * 1000.0
      molesOfUnitCells = grams / molarMass
    elsif from == "mg"
      grams = value / 1000.0
      molesOfUnitCells = grams / molarMass
    end

    # puts "moles of unit cells is #{molesOfUnitCells}"


    if to == "cm3"
      return molesOfUnitCells * volumeMolCm3
    elsif to == "g"
      return molesOfUnitCells * molarMass
    elsif to == "l"
      cm3 = molesOfUnitCells * volumeMolCm3
      return cm3 / 1000.0
    elsif to == "kg"
      return (molesOfUnitCells * molarMass) / 1000.0
    elsif to == "mg"
      return (molesOfUnitCells * molarMass) * 1000.0
    end
  end

  def convert_gas_unit(from, to, value, molarMass, tempK, pressureAtm)
    r = 0.082057
    tempSTP = 273.15
    atmSTP = 1

    supported = ["cm3", "cm3(STP)", "g", "mg", "mmol", "mol"]
    raise UnsupportedGasUnit.new("#{from} is not a supported gas unit") if supported.index(from).nil?
    raise UnsupportedGasUnit.new("#{to} is not a supported gas unit") if supported.index(to).nil?

    moles = nil

    # Convert everything into grams
    if from == "mg"
      g = value / 1000
      moles = g / molarMass
    elsif from == "mol"
      moles = value
    elsif from == "g"
      moles = value / molarMass
    elsif from == "cm3"
      liters = value / 1000.0
      moles = pressureAtm * liters / (r * tempK)
    elsif from == "cm3(STP)"
      liters = value / 1000.0
      moles = atmSTP * liters / (r * tempSTP)
    elsif from == "mmol"
      moles = value / 1000.0
    end

    if to == "mg"
      return moles * molarMass * 1000.0
    elsif to == "mol"
      return moles * molarMass / molarMass
    elsif to == "g"
      return moles * molarMass
    elsif to == "cm3"
      return (moles * r * tempK ) / pressureAtm
    elsif to == "cm3(STP)"
      liters = moles * r * tempSTP / (atmSTP)
      return liters * 1000
    elsif to == "mmol"
      return 1000.0 * moles
    end
  end
end
