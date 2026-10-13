from common.labimpl import load_impl

m = load_impl(__file__)


def test_double():
    assert m.double(3) == 6
