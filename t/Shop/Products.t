# vim:syntax=perl
#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2008 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#------------------------------------------------------------------

# Write a little about what this script tests.
# 
#

use FindBin;
use strict;
use lib "$FindBin::Bin/../lib";
use Test::More;
use Test::Deep;
use Exception::Class;
use Data::Dumper;

use WebGUI::Test; # Must use this before any other WebGUI modules
use WebGUI::Session;
use WebGUI::Text;
use WebGUI::Asset::Sku::Product;

#----------------------------------------------------------------------------
# Init
my $session         = WebGUI::Test->session;

#----------------------------------------------------------------------------
# Tests

my $tests = 22;
plan tests => 1 + $tests;

#----------------------------------------------------------------------------
# put your tests here

my $loaded = use_ok('WebGUI::Shop::Products');

my $storage;
my ($e, $failure);

SKIP: {

    skip 'Unable to load module WebGUI::Shop::Products', $tests unless $loaded;

    #######################################################################
    #
    # import
    #
    #######################################################################

    my $importNode = WebGUI::Asset::Sku::Product->getProductImportNode($session);

    eval { WebGUI::Shop::Products::importProducts($session); };
    $e = Exception::Class->caught();
    isa_ok($e, 'WebGUI::Error::InvalidParam', 'importProducts: error handling for an undefined path to file');
    is($e->error, 'Must provide the path to a file', 'importProducts: error handling for an undefined path to file');

    eval { WebGUI::Shop::Products::importProducts($session, '/path/to/nowhere'); };
    $e = Exception::Class->caught();
    isa_ok($e, 'WebGUI::Error::InvalidFile', 'importProducts: error handling for file that does not exist in the filesystem');
    is($e->error, 'File could not be found', 'importProducts: error handling for file that does not exist in the filesystem');
    cmp_deeply(
        $e,
        methods(
            brokenFile => '/path/to/nowhere',
        ),
        'importTaxData: error handling for file that does not exist in the filesystem',
    );

    my $productsFile = WebGUI::Test->getTestCollateralPath('productTables/goodProductTable.csv');

    SKIP: {
        skip 'Root will cause this test to fail since it does not obey file permissions', 3
            if $< == 0;

        my $originalChmod = (stat $productsFile)[2];
        chmod oct(0000), $productsFile;

        eval { WebGUI::Shop::Products::importProducts($session, $productsFile); };
        $e = Exception::Class->caught();
        isa_ok($e, 'WebGUI::Error::InvalidFile', 'importProducts: error handling for file that cannot be read');
        is($e->error, 'File is not readable', 'importProducts: error handling for file that that cannot be read');
        cmp_deeply(
            $e,
            methods(
                brokenFile => $productsFile,
            ),
            'importProducts: error handling for file that that cannot be read',
        );

        chmod $originalChmod, $productsFile;

    }

    eval {
        $failure = WebGUI::Shop::Products::importProducts(
            $session,
            WebGUI::Test->getTestCollateralPath('productTables/missingHeaders.csv'),
        );
    };
    ok (!$failure, 'Product data is not imported when headers are missing');
    $e = Exception::Class->caught();
    isa_ok($e, 'WebGUI::Error::InvalidFile', 'importProducts: a file with a missing header column');
    cmp_deeply(
        $e,
        methods(
            error      => 'Bad header found in the CSV file',
            brokenFile => WebGUI::Test->getTestCollateralPath('productTables/missingHeaders.csv'),
        ),
        'importProducts: error handling for a file with a missing header',
    );

    eval {
        $failure = WebGUI::Shop::Products::importProducts(
            $session,
            WebGUI::Test->getTestCollateralPath('productTables/badHeaders.csv'),
        );
    };
    ok (!$failure, 'Product data is not imported when the headers are wrong');
    $e = Exception::Class->caught();
    isa_ok($e, 'WebGUI::Error::InvalidFile', 'importProducts: a file with bad headers');
    cmp_deeply(
        $e,
        methods(
            error      => 'Bad header found in the CSV file',
            brokenFile => WebGUI::Test->getTestCollateralPath('productTables/badHeaders.csv'),
        ),
        'importProducts: error handling for a file with a missing header',
    );

    my $pass = WebGUI::Shop::Products::importProducts(
        $session,
        WebGUI::Test->getTestCollateralPath('productTables/goodProductTable.csv'),
    );
    ok($pass, 'Products imported');

    my $count = $session->db->quickScalar('select count(*) from Product');
    is($count, 2, 'two products were imported');

    my $soda = WebGUI::Asset::Sku->newBySku($session, 'soda');
    isa_ok($soda, 'WebGUI::Asset::Sku::Product');
    is($soda->getTitle(), 'Sweet Soda-bottled in Oregon', 'Title set correctly for soda');
    my $sodaCollateral = $soda->getAllCollateral('variantsJSON');
    cmp_deeply(
        $sodaCollateral,
        [
            {
                sku       => 'soda-sweet',
                shortdesc => 'Sweet Soda',
                price     => 0.95,
                weight    => 0.95,
                quantity  => 500,
                variantId => ignore(),
            },
        ],
        'collateral set correctly for soda'
    );

    my $shirt = WebGUI::Asset::Sku->newBySku($session, 't-shirt');
    isa_ok($shirt, 'WebGUI::Asset::Sku::Product');
    is($shirt->getTitle(), 'Colored T-Shirts', 'Title set correctly for t-shirt');
    my $shirtCollateral = $shirt->getAllCollateral('variantsJSON');
    cmp_deeply(
        $shirtCollateral,
        [
            {
                sku       => 'red-t-shirt',
                shortdesc => 'Red T-Shirt',
                price     => '5.00',
                weight    => '1.33',
                quantity  => '1000',
                variantId => ignore(),
            },
            {
                sku       => 'blue-t-shirt',
                shortdesc => 'Blue T-Shirt',
                price     => '5.25',
                weight    => '1.33',
                quantity  => '2000',
                variantId => ignore(),
            },
        ],
        'collateral set correctly for shirt'
    );

}

#----------------------------------------------------------------------------
# Cleanup
END {
    my $getAProduct = WebGUI::Asset::Sku::Product->getIsa($session);
    while (my $product = $getAProduct->()) {
        $product->purge;
    }
}
