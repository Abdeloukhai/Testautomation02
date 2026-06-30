#!/usr/bin/env python3
"""
Python Installation Checker
Run this script to verify your Python environment is working correctly.
"""

import sys
import platform
import os
import importlib

def check_python_version():
    """Check if Python version meets requirements"""
    version = sys.version_info
    print(f"✓ Python Version: {version.major}.{version.minor}.{version.micro}")
    
    if version.major >= 3:
        if version.minor >= 7:
            print("  ✓ Version 3.7+ detected (good for modern packages)")
        else:
            print("  ⚠ Warning: Version 3.6 or earlier (some packages may not work)")
    else:
        print("  ✗ ERROR: Python 2 is outdated and unsupported. Please install Python 3.7+")
        return False
    return True

def check_pip():
    """Check if pip is available"""
    try:
        import pip
        print(f"✓ pip Version: {pip.__version__}")
        return True
    except ImportError:
        print("✗ pip NOT FOUND - package installer is missing")
        return False

def check_common_packages():
    """Check if common automation packages are available"""
    packages = {
        'robotframework': 'Robot Framework',
        'robotframework-browser': 'Browser Library',
        'selenium': 'Selenium',
        'requests': 'Requests (HTTP library)'
    }
    
    print("\n📦 Checking Common Packages:")
    installed = []
    missing = []
    
    for package, name in packages.items():
        try:
            module = importlib.import_module(package.replace('-', '_'))
            version = getattr(module, '__version__', 'unknown')
            print(f"  ✓ {name}: {version}")
            installed.append(package)
        except ImportError:
            print(f"  ✗ {name}: NOT INSTALLED")
            missing.append(package)
    
    return installed, missing

def check_environment():
    """Check system environment details"""
    print("\n🖥 System Information:")
    print(f"  OS: {platform.system()} {platform.release()}")
    print(f"  Architecture: {platform.machine()}")
    print(f"  Python Executable: {sys.executable}")
    print(f"  Working Directory: {os.getcwd()}")
    
    # Check PATH
    path = os.environ.get('PATH', '')
    python_in_path = any('python' in p.lower() for p in path.split(os.pathsep))
    print(f"  Python in PATH: {'✓ Yes' if python_in_path else '✗ No'}")

def provide_recommendations(missing_packages):
    """Give helpful installation commands"""
    if missing_packages:
        print("\n💡 Recommendations:")
        print("  To install missing packages, run:")
        
        if 'robotframework' in missing_packages:
            print("    pip install robotframework")
        if 'robotframework-browser' in missing_packages:
            print("    pip install robotframework-browser")
            print("    rfbrowser init")
        if 'selenium' in missing_packages:
            print("    pip install selenium")
        if 'requests' in missing_packages:
            print("    pip install requests")

def main():
    """Main execution"""
    print("=" * 50)
    print("🐍 Python Installation Checker")
    print("=" * 50)
    
    # Run checks
    version_ok = check_python_version()
    pip_ok = check_pip()
    check_environment()
    installed, missing = check_common_packages()
    
    # Summary
    print("\n" + "=" * 50)
    print("📊 SUMMARY")
    print("=" * 50)
    
    if version_ok and pip_ok:
        print("✓ Python is installed and configured correctly")
        if installed:
            print(f"✓ Found {len(installed)} useful packages")
        if missing:
            print(f"⚠ Missing {len(missing)} packages (see recommendations)")
    else:
        print("✗ Python environment needs attention")
    
    provide_recommendations(missing)
    
    # Exit with appropriate code
    if version_ok and pip_ok:
        print("\n✅ Environment is ready for automation!")
        sys.exit(0)
    else:
        print("\n❌ Please fix the issues above before proceeding")
        sys.exit(1)

if __name__ == "__main__":
    main()