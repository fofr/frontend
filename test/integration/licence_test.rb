require 'integration_test_helper'
require 'gds_api/test_helpers/mapit'

class LicenceLookupTest < ActionDispatch::IntegrationTest
  include GdsApi::TestHelpers::Mapit

  context "given a location specific licence" do
    setup do
      mapit_has_a_postcode_and_areas("SW1A 1AA", [51.5010096, -0.1415870], [
        { "ons" => "00BK", "govuk_slug" => "westminster", "name" => "Westminster City Council", "type" => "LBO" },
        { "name" => "Greater London Authority", "type" => "GLA" }
      ])

      westminster = {
        "id" => 2432,
        "codes" => {
          "ons" => "00BK",
          "gss" => "E07000198",
          "govuk_slug" => "westminster"
        },
        "name" => "Westminster"
      }

      mapit_has_area_for_code('govuk_slug', 'westminster', westminster)
      mapit_does_not_have_area_for_code('govuk_slug', 'not-a-valid-council-name')

      @artefact = artefact_for_slug('licence-to-kill').merge(
        "title" => "Licence to kill",
        "format" => "licence",
        "in_beta" => true,
        "updated_at" => "2012-10-02T15:21:03+00:00",
        "details" => {
          "format" => "Licence",
          "licence_overview" => "You only live twice, Mr Bond.\n",
          "licence" => {
            "location_specific" => true,
            "availability" => ["England", "Wales"],
            "authorities" => [{
              "name" => "Westminster City Council",
              "slug" => "westminster",
              "contact" => {
                "website" => "http://westminster.gov.uk/",
                "email" => "blah@westminster.gov.uk",
                "phone" => "02012345678",
                "address" => "Westminster City Hall, 64 Victoria Street"
              },
              "actions" => {
                "apply" => [
                  {
                    "url" => "/licence-to-kill/westminster/apply-1",
                    "description" => "Apply for your licence to kill",
                    "payment" => "none",
                    "introduction" => "This licence is issued shaken, not stirred."
                  }, {
                    "url" => "/licence-to-kill/westminster/apply-2",
                    "description" => "Apply for your licence to hold gadgets",
                    "payment" => "none",
                    "introduction" => "Q-approval required."
                  }
                ],
                "renew" => [
                  {
                    "url" => "/licence-to-kill/westminster/renew-1",
                    "description" => "Renew your licence to kill",
                    "payment" => "none",
                    "introduction" => ""
                  }
                ]
              }
            }]
          }
        })

      content_api_and_content_store_have_page('licence-to-kill', @artefact)
    end

    context "when visiting the licence search page" do
      setup do
        visit '/licence-to-kill'
      end

      should "render the licence page" do
        assert_equal 200, page.status_code

        within 'head', visible: :all do
          assert page.has_selector?("title", text: "Licence to kill - GOV.UK", visible: :all)
          assert page.has_selector?("link[rel=alternate][type='application/json'][href='/api/licence-to-kill.json']", visible: :all)
        end

        within '#content' do
          within ".page-header" do
            assert page.has_content?("Licence to kill")
          end

          within ".postcode-search-form" do
            assert page.has_field?("Enter a postcode")
            assert page.has_button?("Find")
          end

          assert page.has_no_content?("Please enter a valid full UK postcode.")

          within "#overview" do
            assert page.has_content?("Overview")
            assert page.has_content? "You only live twice, Mr Bond."
          end

          within '.article-container' do
            assert page.has_selector?(shared_component_selector('beta_label'))
            assert page.has_selector?(".modified-date", text: "Last updated: 2 October 2012")
          end
        end

        assert_breadcrumb_rendered
        assert_related_items_rendered
      end

      should "add google analytics tags for postcodeSearchStarted" do
        track_category = page.find('.postcode-search-form')['data-track-category']
        track_action = page.find('.postcode-search-form')['data-track-action']

        assert_equal "postcodeSearch:licence", track_category
        assert_equal "postcodeSearchStarted", track_action
      end
    end

    context "when visiting the licence with a valid postcode" do
      setup do
        visit '/licence-to-kill'

        fill_in 'postcode', with: "SW1A 1AA"
        click_button('Find')
      end

      should "redirect to the appropriate authority slug" do
        assert_equal "/licence-to-kill/westminster", current_path
      end

      should "display the authority name" do
        assert page.has_content?("Westminster")
      end

      should "show available licence actions" do
        within("#content nav") do
          assert page.has_link? "How to apply", href: '/licence-to-kill/westminster/apply'
          assert page.has_link? "How to renew", href: '/licence-to-kill/westminster/renew'
        end
      end

      should "show overview section" do
        within("#overview") do
          assert page.has_content?("You only live twice, Mr Bond.")
        end
      end

      context "when visiting a licence action" do
        setup do
          click_link "How to apply"
        end

        should "display the page content" do
          assert page.has_content? "Licence to kill"
          assert page.has_selector? "h1", text: "How to apply"
        end

        should "display a button to apply for the licence" do
          assert page.has_link? "Apply online", href: "/licence-to-kill/westminster/apply-1"
        end
      end

      should "return a 404 for an invalid action" do
        visit "/licence-to-kill/westminster/blah"
        assert_equal 404, page.status_code

        visit "/licence-to-kill/westminster/change"
        assert_equal 404, page.status_code
      end

      should "return a 404 for an invalid authority" do
        visit "/licence-to-kill/not-a-valid-council-name"

        assert_equal 404, page.status_code
      end
    end

    context "when visiting the licence with an invalid formatted postcode" do
      setup do
        mapit_does_not_have_a_bad_postcode("Not valid")
        visit '/licence-to-kill'

        fill_in 'postcode', with: "Not valid"
        click_button('Find')
      end

      should "remain on the licence page" do
        assert_equal "/licence-to-kill", current_path
      end

      should "see an error message" do
        assert page.has_content? "This isn't a valid postcode."
      end

      should "re-populate the invalid input" do
        assert page.has_field? "postcode", with: "Not valid"
      end
    end

    context "when visiting the licence with a postcode not present in MapIt" do
      setup do
        mapit_does_not_have_a_postcode("AB1 2AB")

        visit '/licence-to-kill'

        fill_in 'postcode', with: "AB1 2AB"
        click_button('Find')
      end

      should "remain on the licence page" do
        assert_equal "/licence-to-kill", current_path
      end

      should "see an error message" do
        assert page.has_content? "We couldn't find this postcode."
      end

      should "re-populate the invalid input" do
        assert page.has_field? "postcode", with: "AB1 2AB"
      end
    end

    context "when visiting the licence with a postcode with no areas in MapIt" do
      setup do
        mapit_has_a_postcode_and_areas("XM4 5HQ", [0.00, -0.00], {})

        visit '/licence-to-kill'

        fill_in 'postcode', with: "XM4 5HQ"
        click_button('Find')
      end

      should "remain on the licence page" do
        assert_equal "/licence-to-kill", current_path
      end

      should "see an error message" do
        assert page.has_content? "We couldn't find a council for this postcode."
      end

      should "re-populate the invalid input" do
        assert page.has_field? "postcode", with: "XM4 5HQ"
      end
    end

    context "when previewing the page" do
      should "render the page" do
        content_api_and_content_store_have_unpublished_page("licence-to-kill", 5, @artefact)

        visit "/licence-to-kill?edition=5"

        assert_equal 200, page.status_code

        within '#content' do
          within 'header' do
            assert page.has_content?("Licence to kill")
          end
        end

        assert_current_url "/licence-to-kill?edition=5"
      end
    end

    context "which does not exist in licensify for an authority" do
      setup do
        artefact = artefact_for_slug('licence-to-kill').merge(
          "title" => "Licence to kill",
          "format" => "licence",
          "details" => {
            "format" => "Licence"
          }
        )

        content_api_and_content_store_have_page('licence-to-kill', artefact)
        content_api_and_content_store_have_page_with_snac_code("licence-to-kill", "30UN", artefact)

        south_ribble = {
          "id" => 2432,
          "codes" => {
            "ons" => "30UN",
            "gss" => "E07000198",
            "govuk_slug" => "south-ribble"
          },
          "name" => "South Ribble"
        }

        mapit_has_area_for_code('govuk_slug', 'south-ribble', south_ribble)
      end

      should "show message to contact local council" do
        visit '/licence-to-kill/south-ribble'

        assert page.status_code == 200
        assert page.has_content?('Contact your local council')
      end
    end
  end

  context "given a non-location specific licence" do
    context "with multiple authorities" do
      setup do
        artefact = artefact_for_slug('licence-to-turn-off-a-telescreen').merge(
          "title" => "Licence to turn off a telescreen",
          "format" => "licence",
          "details" => {
            "format" => "Licence",
            "licence" => {
              "location_specific" => false,
              "availability" => ["England", "Wales"],
              "authorities" => [{
                "name" => "Ministry of Plenty",
                "slug" => "miniplenty",
                "actions" => {
                  "apply" => [{
                    "url" => "/licence-to-turn-off-a-telescreen/minsitry-of-plenty/apply-1",
                    "description" => "Apply for your licence to turn off a telescreen",
                    "payment" => "none",
                    "introduction" => ""
                  }]
                }
              }, {
                "name" => "Ministry of Love",
                "slug" => "miniluv",
                "actions" => {
                  "apply" => [{
                    "url" => "/licence-to-turn-off-a-telescreen/minsitry-of-love/apply-1",
                    "description" => "Apply for your licence to turn off a telescreen",
                    "payment" => "none",
                    "introduction" => ""
                  }]
                }
              }, {
                "name" => "Ministry of Truth",
                "slug" => "minitrue",
                "actions" => {
                  "apply" => [{
                    "url" => "/licence-to-turn-off-a-telescreen/minsitry-of-truth/apply-1",
                    "description" => "Apply for your licence to turn off a telescreen",
                    "payment" => "none",
                    "introduction" => ""
                  }]
                }
              }, {
                "name" => "Ministry of Peace",
                "slug" => "minipax",
                "actions" => {
                  "apply" => [{
                    "url" => "/licence-to-turn-off-a-telescreen/minsitry-of-peace/apply-1",
                    "description" => "Apply for your licence to turn off a telescreen",
                    "payment" => "none",
                    "introduction" => ""
                  }]
                }
              }]
            }
          }
        )
        content_api_and_content_store_have_page('licence-to-turn-off-a-telescreen', artefact)
      end

      context "when visiting the licence without specifying an authority" do
        setup do
          visit '/licence-to-turn-off-a-telescreen'
        end

        should "display the title" do
          assert page.has_content?('Licence to turn off a telescreen')
        end

        should "see the available authorities in a list" do
          assert page.has_content?('Ministry of Peace')
          assert page.has_content?('Ministry of Love')
          assert page.has_content?('Ministry of Truth')
          assert page.has_content?('Ministry of Plenty')
        end

        context "when selecting an authority" do
          setup do
            choose 'Ministry of Love'
            click_button "Get started"
          end

          should "redirect to the authority slug" do
            assert_equal "/licence-to-turn-off-a-telescreen/miniluv", current_path
          end

          should "display interactions for licence" do
            click_on "How to apply"
            assert page.has_link? "Apply online", href: '/licence-to-turn-off-a-telescreen/minsitry-of-love/apply-1'
          end
        end
      end
    end

    context "with a single authority" do
      setup do
        artefact = artefact_for_slug('licence-to-turn-off-a-telescreen').merge(
          "title" => "Licence to turn off a telescreen",
          "format" => "licence",
          "details" => {
            "format" => "Licence",
            "licence_overview" => "The place where there is no darkness.\n",
            "licence" => {
              "location_specific" => false,
              "availability" => ["England", "Wales"],
              "authorities" => [{
                "name" => "Ministry of Love",
                "slug" => "miniluv",
                "actions" => {
                  "apply" => [{
                    "url" => "/licence-to-turn-off-a-telescreen/minsitry-of-love/apply-1",
                    "description" => "Apply for your licence to turn off a telescreen",
                    "payment" => "none",
                    "introduction" => ""
                  }]
                }
              }]
            }
          }
        )
        content_api_and_content_store_have_page('licence-to-turn-off-a-telescreen', artefact)
      end

      context "when visiting the licence" do
        setup do
          visit '/licence-to-turn-off-a-telescreen'
        end

        should "display the title" do
          assert page.has_content?('Licence to turn off a telescreen')
        end

        should "show licence actions for the single authority" do
          within("#content nav") do
            assert page.has_link? "How to apply", href: '/licence-to-turn-off-a-telescreen/miniluv/apply'
          end
        end

        should "display the interactions for licence" do
          click_on "How to apply"
          assert page.has_link? "Apply online", href: '/licence-to-turn-off-a-telescreen/minsitry-of-love/apply-1'
        end

        should "show overview section" do
          within("#overview") do
            assert page.has_content?("The place where there is no darkness.")
          end
        end
      end
    end
  end

  context "given a licence edition with continuation link" do
    setup do
      artefact = artefact_for_slug('artistic-license').merge(
        "title" => "Artistic License",
        "format" => "licence",
        "details" => {
          "format" => "Licence",
          "licence" => {
            "location_specific" => false,
              "availability" => ["England", "Wales"],
              "authorities" => [{
              "name" => "Ministry of Love",
              "slug" => "miniluv",
              "actions" => {
                "apply" => [{
                  "url" => "/licence-to-turn-off-a-telescreen/minsitry-of-love/apply-1",
                  "description" => "Apply for your licence to turn off a telescreen",
                   "payment" => "none",
                   "introduction" => ""
                  }]
                }
              }]
            },
          "will_continue_on" => "another planet",
          "continuation_link" => "http://gov.uk/blah"
        }
      )
      content_api_and_content_store_have_page('artistic-license', artefact)
    end

    context "when visiting the licence" do
      setup do
        visit '/artistic-license'
      end

      should "not see a location form" do
        assert ! page.has_field?('postcode')
      end

      should "see a 'Start now' button" do
        assert page.has_content?('Start now')
      end
    end

    context "when visiting the licence with an authority slug" do
      setup do
        visit '/artistic-license/miniluv'
      end

      should "redirect to the search page" do
        assert_current_url '/artistic-license'
      end
    end
  end

  context "given a licence which does not exist in licensify" do
    setup do
      artefact = artefact_for_slug('licence-to-kill').merge(
        "title" => "Licence to kill",
        "format" => "licence",
        "details" => {
          "format" => "Licence",
          "licence" => {}
        },
        "tags" => [],
        "related" => []
      )
      content_api_and_content_store_have_page("licence-to-kill", artefact)
    end

    should "show message to contact local council" do
      visit '/licence-to-kill'

      assert page.has_content?('Contact your local council')
    end
  end

  context "given that licensify is down" do
    setup do
      artefact = artefact_for_slug('licence-to-kill').merge(
        "title" => "Licence to kill",
        "format" => "licence",
        "details" => {
          "format" => "Licence",
          "licence" => {
            "error" => "http_error"
          }
        }
      )
      content_api_and_content_store_have_page('licence-to-kill', artefact)
    end

    should "not blow the stack" do
      visit '/licence-to-kill'
      assert page.status_code == 200
    end

    should "show message to contact local council" do
      visit '/licence-to-kill'
      assert page.has_content?('Contact your local council')
    end
  end
end