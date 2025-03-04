// import { errorValueToString } from "../../src/js/index";
import { testRun } from "./TestHelpers";
import * as fc from "fast-check";

describe("Scalar manipulation is well-modeled by javascript math", () => {
  test("in the case of natural logarithms", () => {
    fc.assert(
      fc.property(fc.float(), (x) => {
        let squiggleString = `log(${x})`;
        let squiggleResult = testRun(squiggleString);
        if (x == 0) {
          expect(squiggleResult.value).toEqual(-Infinity);
        } else if (x < 0) {
          expect(squiggleResult.value).toEqual(
            "somemessage (confused why a test case hasn't pointed out to me that this message is bogus)"
          );
        } else {
          expect(squiggleResult.value).toEqual(Math.log(x));
        }
      })
    );
  });

  test("in the case of addition (with assignment)", () => {
    fc.assert(
      fc.property(fc.float(), fc.float(), fc.float(), (x, y, z) => {
        let squiggleString = `x = ${x}; y = ${y}; z = ${z}; x + y + z`;
        let squiggleResult = testRun(squiggleString);
        expect(squiggleResult.value).toBeCloseTo(x + y + z);
      })
    );
  });
});
