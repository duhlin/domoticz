require 'domoticz/schedule'

module Domoticz
  describe Schedule do
    subject do
      s = Schedule.new
      s.data = {
        'Days' => 1, # only monday 
        'Time' => '07:00',
        'TimerType' => 2
      }
      s
    end
    before(:each) do
      allow(Time).to receive(:now).and_return(now)
    end
    describe '#next_date' do
      context 'when now is a week day for which the schedule applies' do
        context 'when current time is before "Date"' do
          let(:now) { Time.new(2018, 11, 26, 6, 55) } # monday
          it 'returns the same day at "Date"' do
            expect(subject.next_date).to eq(
              Time.new(now.year, now.month, now.day, 7, 0)
            )
          end
        end
        context 'when current time is after or just at "Date"' do
          let(:now) { Time.new(2018, 11, 26, 7, 0) } # monday
          it 'returns the next day for which day at "Date"' do
            expect(subject.next_date).to eq(
              Time.new(now.year, now.month, now.day, 7, 0).next_day(7)
            )
          end
        end
      end
    end
  end
end
