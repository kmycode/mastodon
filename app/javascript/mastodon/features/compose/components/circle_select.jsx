import PropTypes from 'prop-types';
import { PureComponent } from 'react';

import { injectIntl } from 'react-intl';

import ImmutablePropTypes from 'react-immutable-proptypes';


import Select, { NonceProvider } from 'react-select';

class CircleSelect extends PureComponent {

  static propTypes = {
    unavailable: PropTypes.bool,
    intl: PropTypes.object.isRequired,
    circles: ImmutablePropTypes.map,
    circleId: PropTypes.string,
    onChange: PropTypes.func.isRequired,
  };

  handleClick = value => {
    this.props.onChange(value.value);
  };

  noOptionsMessage = () => '';

  render () {
    const { unavailable, circles, circleId } = this.props;

    if (unavailable) {
      return null;
    }

    const listOptions = circles.toArray().filter((circle) => circle).map((circle) => {
      return { value: circle[1].get('id'), label: circle[1].get('title') };
    });
    const listValue = listOptions.find((opt) => opt.value === circleId);

    return (
      <div className='compose-form__circle-select'>
        <NonceProvider nonce={document.querySelector('meta[name=style-nonce]').content} cacheKey='circles'>
          <Select
            value={listValue}
            options={listOptions}
            noOptionsMessage={this.noOptionsMessage}
            onChange={this.handleClick}
            className='column-content-select__container'
            classNamePrefix='column-content-select'
            name='circles'
            defaultOptions
          />
        </NonceProvider>
      </div>
    );
  }

}

export default injectIntl(CircleSelect);
