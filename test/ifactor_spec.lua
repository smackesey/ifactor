local ifactor = require('ifactor')

describe("some basics", function()

  local bello = function(boo)
    return "bello " .. boo
  end

  local bounter

  before_each(function()
    bounter = 0
  end)

  it("some test", function()
    bounter = 100
    assert.equals("bello Brian", bello("Brian"))
  end)

  it("some other test", function()
    assert.equals(0, bounter)
  end)
end)

describe("start", function()

  after_each(function()
    local success, result = pcall(ifactor.stop)
    if not success then
      ifactor.ACTIVE_INSTANCE = nil
    end
  end)

  it("starts with valid args", function()

  end)



end)
