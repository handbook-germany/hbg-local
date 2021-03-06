# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
require_relative '../test_helper'

class OffersHelperTest < ActionView::TestCase
  include OffersHelper

  let(:offer) { offers(:basic) }

  describe '#tel_format' do
    it 'should format a phone number' do
      tel_format('3656558').must_equal ' 36 56 55 8'
    end
  end

  describe '#offer_with_contacts' do
    before do
      offer.contact_people << contact_people(:contact_two)
    end

    it 'orders contacts alphabetically by last name' do
      last_names = offer.contact_people.pluck(:last_name).sort
      offer_with_contacts(offer).first.last_name.must_equal(last_names.first)
    end
  end

  describe '#display_contacts?' do
    describe 'with no spoc contact and no hidden contacts' do
      it 'should equal true' do
        display_contacts?(offer, offer.contact_people.first).must_equal true
      end
    end

    describe 'with no spoc contact and hidden contacts' do
      before do
        offer.update_columns hide_contact_people: true
      end

      it 'should equal false' do
        display_contacts?(offer, offer.contact_people.first).must_equal false
      end
    end

    describe 'with a spoc contact and hidden contacts' do
      before do
        offer.update_columns hide_contact_people: true
        offer.contact_people.first.update_columns spoc: true
      end

      it 'should equal true' do
        display_contacts?(offer, offer.contact_people.first).must_equal true
      end
    end

    describe 'with a spoc contact and no hidden contacts' do
      before do
        offer.contact_people.first.update_columns spoc: true
      end
      it 'should equal true' do
        display_contacts?(offer, offer.contact_people.first).must_equal true
      end
    end
  end

  describe '#contact_name' do
    describe 'with only the operational name present' do
      before do
        offer.contact_people.first.update_columns gender: '',
                                                  last_name: '',
                                                  first_name: '',
                                                  operational_name: 'CEO'
      end
      it "should return the name as 'CEO'" do
        contact_name(offer.contact_people.first).must_equal 'CEO'
      end
    end

    describe 'with the first name present' do
      before do
        offer.contact_people.first.update_columns gender: 'female',
                                                  last_name: '',
                                                  first_name: 'Jane',
                                                  operational_name: 'CEO'
      end
      it "should return the name as 'Jane'" do
        contact_name(offer.contact_people.first).must_equal 'Jane'
      end
    end

    describe 'with the full name present' do
      describe 'with no gender or academic title present' do
        before do
          offer.contact_people.first.update_columns gender: '',
                                                    academic_title: '',
                                                    last_name: 'Doe',
                                                    first_name: 'Jane',
                                                    operational_name: 'CEO'
        end
        it "should return the name as 'Jane'" do
          contact_name(offer.contact_people.first).must_equal 'Jane Doe'
        end
      end

      describe 'with a gender and no academic title present' do
        before do
          offer.contact_people.first.update_columns gender: 'female',
                                                    academic_title: '',
                                                    last_name: 'Doe',
                                                    first_name: 'Jane',
                                                    operational_name: 'CEO'
        end
        it "should return 'Frau Jane Doe'" do
          contact_name(offer.contact_people.first).must_equal 'Frau Jane Doe'
        end
      end

      describe 'with a gender and an academic title present' do
        before do
          offer.contact_people.first.update_columns gender: 'female',
                                                    academic_title: 'prof_dr',
                                                    last_name: 'Doe',
                                                    first_name: 'Jane',
                                                    operational_name: 'CEO'
        end
        it "should return 'Frau Prof. Dr. Jane Doe'" do
          contact_name(offer.contact_people.first)
            .must_equal 'Frau Prof. Dr. Jane Doe'
        end
      end
    end
  end

  describe '#contact_gender' do
    before { offer.contact_people.first.update_columns gender: 'female' }

    it "should return the gender as 'Frau'" do
      contact_gender(offer.contact_people.first).must_equal 'Frau '
    end
  end

  describe '#contact_academic_title' do
    before do
      offer.contact_people.first
           .update_columns academic_title: 'prof_dr'
    end

    it "should return the gender as 'Frau'" do
      contact_academic_title(offer.contact_people.first).must_equal 'Prof. Dr. '
    end
  end

  describe '#contact_full_name' do
    describe 'with first and last name present' do
      before do
        offer.contact_people.first.update_columns first_name: 'Jane',
                                                  last_name: 'Doe'
      end

      it "should return the full name as 'Jane Doe'" do
        contact_full_name(offer.contact_people.first).must_equal 'Jane Doe'
      end
    end

    describe 'with only the last name present' do
      before do
        offer.contact_people.first.update_columns first_name: '',
                                                  last_name: 'Doe'
      end

      it "should return 'Doe'" do
        contact_full_name(offer.contact_people.first).must_equal 'Doe'
      end
    end

    describe 'with only the first name present' do
      before do
        offer.contact_people.first.update_columns first_name: 'Jane',
                                                  last_name: ''
      end

      it 'should return nil' do
        assert_nil contact_full_name(offer.contact_people.first)
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
