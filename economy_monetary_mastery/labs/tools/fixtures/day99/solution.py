"""Fixture lab used to test tools/verify_labs.py."""


def double(x):
    return 2 * x


def main():
    print(double(2))


if __name__ == "__main__":
    main()
